///|
pub fn flatten_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("flatten", invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn flatten_summary() -> String {
  "Sequence nested values through explicit locals to establish Binaryen Flat IR."
}

///|
/// Analysis-only summary of Binaryen Flat IR contract violations in one HOT function.
pub(all) struct FlattenFlatnessReport {
  mut rich_operand_count : Int
  mut value_control_count : Int
  mut local_tee_count : Int
  mut control_local_set_count : Int
  mut body_value_flow_count : Int
  mut unsupported_count : Int
} derive(Eq, Debug)

///|
pub fn FlattenFlatnessReport::empty() -> FlattenFlatnessReport {
  {
    rich_operand_count: 0,
    value_control_count: 0,
    local_tee_count: 0,
    control_local_set_count: 0,
    body_value_flow_count: 0,
    unsupported_count: 0,
  }
}

///|
pub fn FlattenFlatnessReport::is_flat(self : FlattenFlatnessReport) -> Bool {
  self.rich_operand_count == 0 &&
  self.value_control_count == 0 &&
  self.local_tee_count == 0 &&
  self.control_local_set_count == 0 &&
  self.body_value_flow_count == 0 &&
  self.unsupported_count == 0
}

///|
/// Missing local prerequisites for Binaryen-equivalent legacy EH repair.
priv struct FlattenEhRepairRequirement {
  mut needs_catch_payload_tracking : Bool
  mut needs_exceptional_transfer_repair : Bool
}

///|
fn FlattenEhRepairRequirement::empty() -> FlattenEhRepairRequirement {
  {
    needs_catch_payload_tracking: false,
    needs_exceptional_transfer_repair: false,
  }
}

///|
fn FlattenEhRepairRequirement::is_clear(
  self : FlattenEhRepairRequirement,
) -> Bool {
  !self.needs_catch_payload_tracking && !self.needs_exceptional_transfer_repair
}

///|
/// Classify legacy EH prerequisites before any flatten mutation.
fn flatten_eh_repair_requirement(
  func : @ir.HotFunc,
) -> FlattenEhRepairRequirement {
  let requirement = FlattenEhRepairRequirement::empty()
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Catch | @ir.HotOp::CatchAll =>
        requirement.needs_catch_payload_tracking = true
      @ir.HotOp::Rethrow | @ir.HotOp::Delegate =>
        requirement.needs_exceptional_transfer_repair = true
      _ => ()
    }
  }
  requirement
}

///|
fn flatten_op_is_control_structure(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
fn flatten_node_is_simple_operand(func : @ir.HotFunc, node_id : Int) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::Unreachable
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::GlobalGet => true
    @ir.HotOp::Unary =>
      @ir.hot_node_exact_instr(func, node_id) ==
      Some(@lib.Instruction::ref_as_non_null())
    _ => false
  }
}

///|
fn flatten_operand_slot_count(func : @ir.HotFunc, node_id : Int) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Try | @ir.HotOp::TryTable => 0
    @ir.HotOp::Loop =>
      @ir.hot_label_branch_arity(
        func,
        @ir.hot_control_node_label(func, node_id),
      )
    @ir.HotOp::If => 1
    _ => @ir.hot_child_count(func, node_id)
  }
}

///|
fn flatten_op_is_unsupported(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
/// Classify the current HOT function without mutating it.
pub fn flatten_classify_hot(func : @ir.HotFunc) -> FlattenFlatnessReport {
  let report = FlattenFlatnessReport::empty()
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if flatten_op_is_unsupported(node.op) {
      report.unsupported_count += 1
    }
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::If | @ir.HotOp::Try =>
        if @ir.hot_type_result_arity(func, node.ty) > 0 {
          report.value_control_count += 1
        }
      @ir.HotOp::LocalTee => report.local_tee_count += 1
      @ir.HotOp::LocalSet =>
        if @ir.hot_child_count(func, node_id) == 1 {
          let child = @ir.hot_node_get(
            func,
            @ir.hot_child_get(func, node_id, 0),
          )
          if flatten_op_is_control_structure(child.op) {
            report.control_local_set_count += 1
          }
        }
      _ => ()
    }
    for slot = 0
        slot < flatten_operand_slot_count(func, node_id)
        slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
        let local_set_value_is_allowed = match node.op {
          @ir.HotOp::LocalSet =>
            !flatten_op_is_control_structure(
              @ir.hot_node_get(func, child_id).op,
            )
          _ => false
        }
        if !local_set_value_is_allowed &&
          !flatten_node_is_simple_operand(func, child_id) {
          report.rich_operand_count += 1
        }
      }
    }
  }
  let root_count = @ir.hot_root_count(func)
  if root_count > 0 {
    let tail = @ir.hot_root_get(func, root_count - 1)
    if @ir.hot_node_is_live(func, tail) &&
      @ir.hot_node_result_arity(func, tail) > 0 {
      report.body_value_flow_count = 1
    }
  }
  report
}

///|
fn flatten_value_type_is_defaultable(value_type : @lib.ValType) -> Bool {
  match value_type {
    @lib.RefTypeValType(ref_type) => @lib.RefType::is_defaultable(ref_type)
    @lib.BotValType => false
    _ => true
  }
}

///|
fn flatten_build_node_use_counts(func : @ir.HotFunc) -> @ir.HotNodeUseCounts {
  @ir.hot_node_use_counts_build(func)
}

///|
fn flatten_set_region_root(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  root_idx : Int,
  replacement_id : Int,
) -> Int {
  let previous_id = @ir.hot_region_get(func, region_ref, root_idx)
  if previous_id != replacement_id {
    ignore(@ir.hot_region_set(func, region_ref, root_idx, replacement_id))
    pass_mark_mutated(ctx, func)
  }
  previous_id
}

///|
fn flatten_build_label_branch_nodes(func : @ir.HotFunc) -> Array[Array[Int]] {
  let branch_nodes : Array[Array[Int]] = []
  for label_idx = 0; label_idx < func.labels.length(); label_idx = label_idx + 1 {
    branch_nodes.push([])
  }
  let record = fn(label_id : Int, node_id : Int) {
    if label_id >= 0 &&
      label_id < branch_nodes.length() &&
      !branch_nodes[label_id].contains(node_id) {
      branch_nodes[label_id].push(node_id)
    }
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate => record(node.imm0, node_id)
      @ir.HotOp::BrTable => {
        record(@ir.hot_branch_table_default_target(func, node.imm0), node_id)
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          record(label_id, node_id)
        }
      }
      @ir.HotOp::TryTable => {
        let info = @ir.hot_catch_info_get(func, node.imm1)
        for catch_ in info.catches {
          let label_id = match catch_ {
            @ir.HotCatchArm::CatchArm(_, label_id)
            | @ir.HotCatchArm::CatchRefArm(_, label_id)
            | @ir.HotCatchArm::CatchAllArm(label_id)
            | @ir.HotCatchArm::CatchAllRefArm(label_id) => label_id
          }
          record(label_id, node_id)
        }
      }
      _ => ()
    }
  }
  branch_nodes
}

///|
priv struct FlattenBrIfFlowEntry {
  branch_id : Int
  flow : Array[Int]?
}

///|
fn FlattenBrIfFlowEntry::new(
  branch_id : Int,
  flow : Array[Int]?,
) -> FlattenBrIfFlowEntry {
  { branch_id, flow }
}

///|
priv struct FlattenScalarBrIfFlowEntry {
  branch_id : Int
  value_id : Int
  sites : Array[Int]
}

///|
fn FlattenScalarBrIfFlowEntry::new(
  branch_id : Int,
  value_id : Int,
  sites : Array[Int],
) -> FlattenScalarBrIfFlowEntry {
  { branch_id, value_id, sites }
}

///|
priv struct FlattenScalarFlowReplacementEntry {
  value_id : Int
  replacement_id : Int
}

///|
fn FlattenScalarFlowReplacementEntry::new(
  value_id : Int,
  replacement_id : Int,
) -> FlattenScalarFlowReplacementEntry {
  { value_id, replacement_id }
}

///|
fn flatten_br_if_flow_entry_index(
  entries : Array[FlattenBrIfFlowEntry],
  branch_id : Int,
) -> Int {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].branch_id == branch_id {
      return index
    }
  }
  -1
}

///|
fn flatten_scalar_br_if_flow_entry_index(
  entries : Array[FlattenScalarBrIfFlowEntry],
  branch_id : Int,
) -> Int {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].branch_id == branch_id {
      return index
    }
  }
  -1
}

///|
fn flatten_scalar_flow_replacement(
  entries : Array[FlattenScalarFlowReplacementEntry],
  value_id : Int,
) -> Int {
  for entry in entries {
    if entry.value_id == value_id {
      return entry.replacement_id
    }
  }
  -1
}

///|
fn flatten_scalar_flow_replacement_set(
  entries : Array[FlattenScalarFlowReplacementEntry],
  value_id : Int,
  replacement_id : Int,
) -> Unit {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].value_id == value_id {
      entries[index] = FlattenScalarFlowReplacementEntry::new(
        value_id, replacement_id,
      )
      return
    }
  }
  entries.push(FlattenScalarFlowReplacementEntry::new(value_id, replacement_id))
}

///|
priv struct FlattenDeadSuffixEntry {
  table_id : Int
  region_ref : @ir.HotRegionRef
  nodes : Array[Int]
}

///|
fn FlattenDeadSuffixEntry::new(
  table_id : Int,
  region_ref : @ir.HotRegionRef,
  nodes : Array[Int],
) -> FlattenDeadSuffixEntry {
  { table_id, region_ref, nodes }
}

///|
priv struct FlattenTerminalTableEntry {
  node_id : Int
  label_id : Int
  payload_count : Int
  allow_mixed_targets : Bool
  supported : Bool
}

///|
fn FlattenTerminalTableEntry::new(
  node_id : Int,
  label_id : Int,
  payload_count : Int,
  allow_mixed_targets : Bool,
  supported : Bool,
) -> FlattenTerminalTableEntry {
  { node_id, label_id, payload_count, allow_mixed_targets, supported }
}

///|
priv struct FlattenScalarTryEntry {
  try_id : Int
  supported : Bool
}

///|
fn FlattenScalarTryEntry::new(
  try_id : Int,
  supported : Bool,
) -> FlattenScalarTryEntry {
  { try_id, supported }
}

///|
fn flatten_dead_suffix_entry_index(
  entries : Array[FlattenDeadSuffixEntry],
  table_id : Int,
) -> Int {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].table_id == table_id {
      return index
    }
  }
  -1
}

///|
fn flatten_terminal_table_entry_index(
  entries : Array[FlattenTerminalTableEntry],
  node_id : Int,
) -> Int {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].node_id == node_id {
      return index
    }
  }
  -1
}

///|
fn flatten_scalar_try_entry_index(
  entries : Array[FlattenScalarTryEntry],
  try_id : Int,
) -> Int {
  for index = 0; index < entries.length(); index = index + 1 {
    if entries[index].try_id == try_id {
      return index
    }
  }
  -1
}

///|
priv struct FlattenRewriteState {
  label_temps : Array[Array[Int]]
  terminal_payloads : Array[Int]
  sequenced_root_holders : Array[Int]
  sequenced_root_nodes : Array[Int]
  eh_repair_requirement : FlattenEhRepairRequirement
  label_used : @bitset.BitSet
  label_branch_nodes : Array[Array[Int]]
  use_def : @ir.HotNodeUseCounts
  use_count_node_limit : Int
  tuple_br_if_flow_entries : Array[FlattenBrIfFlowEntry]
  multivalue_br_if_flow_entries : Array[FlattenBrIfFlowEntry]
  scalar_br_if_flow_entries : Array[FlattenScalarBrIfFlowEntry]
  scalar_flow_replacement_entries : Array[FlattenScalarFlowReplacementEntry]
  dead_suffix_entries : Array[FlattenDeadSuffixEntry]
  terminal_table_entries : Array[FlattenTerminalTableEntry]
  scalar_try_entries : Array[FlattenScalarTryEntry]
  mut rewrites_started : Bool
}

///|
fn FlattenRewriteState::new(func : @ir.HotFunc) -> FlattenRewriteState {
  let label_temps : Array[Array[Int]] = []
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    label_temps.push([])
  }
  let label_branch_nodes = flatten_build_label_branch_nodes(func)
  let label_used = @bitset.BitSet::new(func.labels.length())
  for label_id = 0
      label_id < label_branch_nodes.length()
      label_id = label_id + 1 {
    label_used[label_id] = !label_branch_nodes[label_id].is_empty()
  }
  {
    label_temps,
    terminal_payloads: [],
    sequenced_root_holders: [],
    sequenced_root_nodes: [],
    eh_repair_requirement: flatten_eh_repair_requirement(func),
    label_used,
    label_branch_nodes,
    use_def: flatten_build_node_use_counts(func),
    use_count_node_limit: @ir.hot_node_count(func),
    tuple_br_if_flow_entries: [],
    multivalue_br_if_flow_entries: [],
    scalar_br_if_flow_entries: [],
    scalar_flow_replacement_entries: [],
    dead_suffix_entries: [],
    terminal_table_entries: [],
    scalar_try_entries: [],
    rewrites_started: false,
  }
}

///|
fn flatten_cached_label_is_used(
  func : @ir.HotFunc,
  label_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  match state {
    Some(state) => pass_label_is_used(label_id, state.label_used)
    None => pass_label_is_used(label_id, pass_compute_label_used(func))
  }
}

///|
fn flatten_label_temps_match_types(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  label_id : Int,
  value_types : Array[@lib.ValType],
) -> Bool {
  if label_id < 0 || label_id >= state.label_temps.length() {
    return false
  }
  let locals = state.label_temps[label_id]
  if locals.length() != value_types.length() {
    return false
  }
  for slot = 0; slot < locals.length(); slot = slot + 1 {
    if @ir.hot_local_type(func, locals[slot]) != Some(value_types[slot]) {
      return false
    }
  }
  true
}

///|
fn flatten_ensure_label_temps(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  label_id : Int,
  value_types : Array[@lib.ValType],
) -> Array[Int]? {
  if label_id < 0 || label_id >= state.label_temps.length() {
    return None
  }
  let locals = state.label_temps[label_id]
  if locals.length() == 0 {
    for value_type in value_types {
      locals.push(@ir.hot_append_body_local(func, value_type))
    }
  } else if !flatten_label_temps_match_types(func, state, label_id, value_types) {
    return None
  }
  Some(locals)
}

///|
fn flatten_br_table_targets_label(
  func : @ir.HotFunc,
  table_id : Int,
  label_id : Int,
) -> Bool {
  if @ir.hot_branch_table_default_target(func, table_id) == label_id {
    return true
  }
  for target in @ir.hot_branch_table_targets(func, table_id) {
    if target == label_id {
      return true
    }
  }
  false
}

///|
fn flatten_terminal_branch_targets_label(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  allow_scalar_payload : Bool,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br if node.imm0 == label_id =>
      @ir.hot_child_count(func, node_id) == 0 ||
      (allow_scalar_payload && @ir.hot_child_count(func, node_id) == 1)
    @ir.HotOp::BrTable if flatten_br_table_targets_label(
        func,
        node.imm0,
        label_id,
      ) =>
      @ir.hot_child_count(func, node_id) == 1 ||
      (allow_scalar_payload && @ir.hot_child_count(func, node_id) == 2)
    _ => false
  }
}

///|
fn flatten_label_uses_are_routed_scalar_brs(
  func : @ir.HotFunc,
  label_id : Int,
) -> Bool {
  let mut saw_target = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br if node.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) != 0 {
          return false
        }
      }
      @ir.HotOp::BrIf if node.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) != 1 {
          return false
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if node.imm0 == label_id => return false
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          node.imm0,
          label_id,
        ) => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) != 1 {
          return false
        }
      }
      _ => ()
    }
  }
  saw_target
}

///|
fn flatten_multivalue_region_tail_matches_types(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  result_types : Array[@lib.ValType],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if result_types.length() <= 1 || root_count < result_types.length() {
    return false
  }
  let tail_start = root_count - result_types.length()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let value_id = @ir.hot_region_get(func, region_ref, tail_start + slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 || value_types[0] != result_types[slot] {
      return false
    }
  }
  true
}

///|
fn flatten_multivalue_region_tail_repeats_tuple(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  result_types : Array[@lib.ValType],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if result_types.length() <= 1 || root_count < result_types.length() {
    return false
  }
  let tail_start = root_count - result_types.length()
  let tuple_id = @ir.hot_region_get(func, region_ref, tail_start)
  for slot = 1; slot < result_types.length(); slot = slot + 1 {
    if @ir.hot_region_get(func, region_ref, tail_start + slot) != tuple_id {
      return false
    }
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake =>
      @ir.hot_type_results(func, tuple.ty) == result_types &&
      @ir.hot_child_count(func, tuple_id) == result_types.length()
    _ => false
  }
}

///|
fn flatten_multivalue_region_tail_tuple_make_values(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  result_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if result_types.length() <= 1 || root_count == 0 {
    return None
  }
  let tail_index = root_count - 1
  let tuple_id = @ir.hot_region_get(func, region_ref, tail_index)
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return None
  }
  if @ir.hot_type_results(func, tuple.ty) != result_types ||
    @ir.hot_child_count(func, tuple_id) != result_types.length() {
    return None
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if @ir.hot_node_use_count(use_counts, tuple_id) != 1 {
    return None
  }
  let values : Array[Int] = []
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      value_types[0] != result_types[slot] ||
      !flatten_node_is_simple_operand(func, value_id) {
      return None
    }
    values.push(value_id)
  }
  Some(values)
}

///|
fn flatten_rewrite_multivalue_region_tail_tuple_make_values(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  region_ref : @ir.HotRegionRef,
  result_types : Array[@lib.ValType],
) -> Array[Int]? {
  if !state.rewrites_started {
    return None
  }
  flatten_multivalue_region_tail_tuple_make_values(
    func,
    region_ref,
    result_types,
    state=Some(state),
  )
}

///|
fn flatten_multivalue_region_tail_tuple_make_has_supported_origins(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  result_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if result_types.length() <= 1 || root_count == 0 {
    return false
  }
  let tail_index = root_count - 1
  let tuple_id = @ir.hot_region_get(func, region_ref, tail_index)
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return false
  }
  if @ir.hot_type_results(func, tuple.ty) != result_types ||
    @ir.hot_child_count(func, tuple_id) != result_types.length() {
    return false
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if @ir.hot_node_use_count(use_counts, tuple_id) != 1 {
    return false
  }
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      value_types[0] != result_types[slot] ||
      !flatten_value_type_is_defaultable(result_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return false
    }
  }
  true
}

///|
fn flatten_replace_multivalue_tuple_make_tail(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  values : Array[Int],
  locals : Array[Int],
) -> Unit {
  let replacement : Array[Int] = []
  for slot = 0; slot < values.length(); slot = slot + 1 {
    replacement.push(@ir.hot_build_local_set(func, locals[slot], values[slot]))
  }
  let removed = pass_splice_region(
    ctx,
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
    1,
    replacement,
  )
  pass_delete_detached_nodes(ctx, func, removed)
}

///|
fn flatten_multivalue_region_tail_reads_locals(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  locals : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if locals.length() <= 1 || root_count < locals.length() {
    return false
  }
  let tail_start = root_count - locals.length()
  for slot = 0; slot < locals.length(); slot = slot + 1 {
    let value_id = @ir.hot_region_get(func, region_ref, tail_start + slot)
    let value = @ir.hot_node_get(func, value_id)
    match value.op {
      @ir.HotOp::LocalGet if value.imm0 == locals[slot] => ()
      _ => return false
    }
  }
  true
}

///|
fn flatten_try_route_multivalue_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  block_id : Int,
) -> Array[Int]? {
  let block = @ir.hot_node_get(func, block_id)
  match block.op {
    @ir.HotOp::Block => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, block.ty)
  if result_types.length() <= 1 {
    return None
  }
  for result_type in result_types {
    if !flatten_value_type_is_defaultable(result_type) {
      return None
    }
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  let label_is_used = flatten_cached_label_is_used(
    func,
    label_id,
    state=Some(state),
  )
  let locals = if label_is_used {
    if !flatten_label_temps_match_types(func, state, label_id, result_types) ||
      !flatten_label_uses_are_routed_scalar_brs(func, label_id) {
      return None
    }
    state.label_temps[label_id]
  } else {
    match flatten_ensure_label_temps(func, state, label_id, result_types) {
      Some(locals) => locals
      None => return None
    }
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return None
  }
  if label_is_used {
    let tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
    if flatten_terminal_branch_targets_label(func, tail_id, label_id, false) {
      @ir.hot_control_result_type_set(func, block_id, @ir.hot_type_void(func))
      return Some(locals)
    }
  }
  let tuple_values = flatten_rewrite_multivalue_region_tail_tuple_make_values(
    func, state, body_ref, result_types,
  )
  if !flatten_multivalue_region_tail_matches_types(func, body_ref, result_types) &&
    tuple_values is None {
    return None
  }
  match tuple_values {
    Some(values) =>
      flatten_replace_multivalue_tuple_make_tail(
        ctx, func, body_ref, values, locals,
      )
    None => {
      let tail_start = body_count - result_types.length()
      if flatten_multivalue_region_tail_reads_locals(func, body_ref, locals) {
        ignore(
          pass_splice_region(
            ctx,
            func,
            body_ref,
            tail_start,
            result_types.length(),
            [],
          ),
        )
      } else {
        for slot = 0; slot < result_types.length(); slot = slot + 1 {
          let value_id = @ir.hot_region_get(func, body_ref, tail_start + slot)
          ignore(
            flatten_set_region_root(
              ctx,
              func,
              body_ref,
              tail_start + slot,
              @ir.hot_build_local_set(func, locals[slot], value_id),
            ),
          )
        }
      }
    }
  }
  @ir.hot_control_result_type_set(func, block_id, @ir.hot_type_void(func))
  Some(locals)
}

///|
fn flatten_try_route_multivalue_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  if_id : Int,
) -> Array[Int]? {
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, if_node.ty)
  if result_types.length() <= 1 {
    return None
  }
  for result_type in result_types {
    if !flatten_value_type_is_defaultable(result_type) {
      return None
    }
  }
  let label_id = @ir.hot_control_node_label(func, if_id)
  let label_is_used = flatten_cached_label_is_used(
    func,
    label_id,
    state=Some(state),
  )
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return None
  }
  let regions = [then_ref, else_ref]
  for region_ref in regions {
    let root_count = @ir.hot_region_root_count(func, region_ref)
    if root_count == 0 {
      return None
    }
    let tail_id = @ir.hot_region_get(func, region_ref, root_count - 1)
    if label_is_used &&
      flatten_terminal_branch_targets_label(func, tail_id, label_id, false) {
      continue
    }
    if !flatten_multivalue_region_tail_matches_types(
        func, region_ref, result_types,
      ) &&
      flatten_rewrite_multivalue_region_tail_tuple_make_values(
        func, state, region_ref, result_types,
      )
      is None {
      return None
    }
  }
  let locals = if label_is_used {
    if !flatten_label_temps_match_types(func, state, label_id, result_types) ||
      !flatten_label_uses_are_routed_scalar_brs(func, label_id) {
      return None
    }
    state.label_temps[label_id]
  } else {
    match flatten_ensure_label_temps(func, state, label_id, result_types) {
      Some(locals) => locals
      None => return None
    }
  }
  for region_ref in regions {
    let root_count = @ir.hot_region_root_count(func, region_ref)
    let tail_id = @ir.hot_region_get(func, region_ref, root_count - 1)
    if label_is_used &&
      flatten_terminal_branch_targets_label(func, tail_id, label_id, false) {
      continue
    }
    match
      flatten_rewrite_multivalue_region_tail_tuple_make_values(
        func, state, region_ref, result_types,
      ) {
      Some(values) =>
        flatten_replace_multivalue_tuple_make_tail(
          ctx, func, region_ref, values, locals,
        )
      None => {
        let tail_start = root_count - result_types.length()
        if flatten_multivalue_region_tail_reads_locals(func, region_ref, locals) {
          ignore(
            pass_splice_region(
              ctx,
              func,
              region_ref,
              tail_start,
              result_types.length(),
              [],
            ),
          )
        } else {
          for slot = 0; slot < result_types.length(); slot = slot + 1 {
            let value_id = @ir.hot_region_get(
              func,
              region_ref,
              tail_start + slot,
            )
            ignore(
              flatten_set_region_root(
                ctx,
                func,
                region_ref,
                tail_start + slot,
                @ir.hot_build_local_set(func, locals[slot], value_id),
              ),
            )
          }
        }
      }
    }
  }
  @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
  Some(locals)
}

///|
fn flatten_multivalue_try_terminal_plain_br_targets_label(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  payload_count : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br if node.imm0 == label_id => {
      let child_count = @ir.hot_child_count(func, node_id)
      child_count == 0 || child_count == payload_count
    }
    _ => false
  }
}

///|
fn flatten_direct_target_control_regions(
  func : @ir.HotFunc,
  owner_id : Int,
) -> Array[@ir.HotRegionRef]? {
  match @ir.hot_node_get(func, owner_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      Some([@ir.hot_region_body_ref(func, owner_id)])
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, owner_id) {
        Some(else_ref) =>
          Some([@ir.hot_region_then_ref(func, owner_id), else_ref])
        None => None
      }
    _ => None
  }
}

///| Build direct structural parent links once, then walk from the legacy try.

///|
/// This is linear in the inspected target-region roots plus target count.
fn flatten_direct_enclosing_target_controls(
  func : @ir.HotFunc,
  inner_id : Int,
  target_controls : Array[Int],
) -> Array[Int]? {
  if inner_id < 0 || inner_id >= @ir.hot_node_count(func) {
    return None
  }
  let node_count = @ir.hot_node_count(func)
  let direct_parent = Array::make(node_count, -1)
  let target_seen = Array::make(node_count, false)
  for owner_id in target_controls {
    if owner_id < 0 ||
      owner_id >= node_count ||
      !@ir.hot_node_is_live(func, owner_id) ||
      target_seen[owner_id] {
      return None
    }
    target_seen[owner_id] = true
    let regions = match flatten_direct_target_control_regions(func, owner_id) {
      Some(regions) => regions
      None => return None
    }
    for region_ref in regions {
      for root_idx = 0
          root_idx < @ir.hot_region_root_count(func, region_ref)
          root_idx = root_idx + 1 {
        let child_id = @ir.hot_region_get(func, region_ref, root_idx)
        if child_id < 0 || child_id >= direct_parent.length() {
          continue
        }
        if direct_parent[child_id] < 0 || direct_parent[child_id] == owner_id {
          direct_parent[child_id] = owner_id
        } else {
          direct_parent[child_id] = -2
        }
      }
    }
  }
  let chain : Array[Int] = []
  let chain_seen = Array::make(node_count, false)
  let mut current = inner_id
  while chain.length() < target_controls.length() {
    let parent = direct_parent[current]
    if parent < 0 || chain_seen[parent] {
      return None
    }
    chain_seen[parent] = true
    chain.push(parent)
    current = parent
  }
  Some(chain)
}

///|
fn flatten_try_table_dead_suffix_subtract_one_multiply_child_nodes(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
  value_id : Int,
  left_id : Int,
  right_id : Int,
  multiply_on_right : Bool,
) -> Array[Int]? {
  let constant_id = if multiply_on_right { left_id } else { right_id }
  let multiply_id = if multiply_on_right { right_id } else { left_id }
  match
    (
      @ir.hot_node_get(func, constant_id).op,
      @ir.hot_node_get(func, multiply_id).op,
    ) {
    (@ir.HotOp::Const, @ir.HotOp::Binary) => ()
    _ => return None
  }
  if @ir.hot_node_exact_instr(func, multiply_id) !=
    Some(@lib.Instruction::i32_mul()) ||
    @ir.hot_child_count(func, multiply_id) != 2 {
    return None
  }
  let multiply_left = @ir.hot_child_get(func, multiply_id, 0)
  let multiply_right = @ir.hot_child_get(func, multiply_id, 1)
  let nested_nodes = [
    root_id, value_id, left_id, right_id, multiply_left, multiply_right,
  ]
  for outer = 0; outer < nested_nodes.length(); outer = outer + 1 {
    for inner = outer + 1; inner < nested_nodes.length(); inner = inner + 1 {
      if nested_nodes[outer] == nested_nodes[inner] {
        return None
      }
    }
  }
  match
    (
      @ir.hot_node_get(func, multiply_left).op,
      @ir.hot_node_get(func, multiply_right).op,
    ) {
    (@ir.HotOp::Const, @ir.HotOp::Const) => ()
    _ => return None
  }
  for owned_id in [left_id, right_id, multiply_left, multiply_right] {
    if @ir.hot_node_use_count(use_def, owned_id) != 1 {
      return None
    }
  }
  Some(nested_nodes)
}

///|
fn flatten_try_table_dead_suffix_two_multiply_children_nodes(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
  value_id : Int,
  left_id : Int,
  right_id : Int,
) -> Array[Int]? {
  match
    (@ir.hot_node_get(func, left_id).op, @ir.hot_node_get(func, right_id).op) {
    (@ir.HotOp::Binary, @ir.HotOp::Binary) => ()
    _ => return None
  }
  if @ir.hot_node_exact_instr(func, left_id) !=
    Some(@lib.Instruction::i32_mul()) ||
    @ir.hot_node_exact_instr(func, right_id) !=
    Some(@lib.Instruction::i32_mul()) ||
    @ir.hot_child_count(func, left_id) != 2 ||
    @ir.hot_child_count(func, right_id) != 2 {
    return None
  }
  let left_multiply_left = @ir.hot_child_get(func, left_id, 0)
  let left_multiply_right = @ir.hot_child_get(func, left_id, 1)
  let right_multiply_left = @ir.hot_child_get(func, right_id, 0)
  let right_multiply_right = @ir.hot_child_get(func, right_id, 1)
  let nested_nodes = [
    root_id, value_id, left_id, right_id, left_multiply_left, left_multiply_right,
    right_multiply_left, right_multiply_right,
  ]
  for outer = 0; outer < nested_nodes.length(); outer = outer + 1 {
    for inner = outer + 1; inner < nested_nodes.length(); inner = inner + 1 {
      if nested_nodes[outer] == nested_nodes[inner] {
        return None
      }
    }
  }
  for
    leaf_id in [
      left_multiply_left, left_multiply_right, right_multiply_left, right_multiply_right,
    ] {
    match @ir.hot_node_get(func, leaf_id).op {
      @ir.HotOp::Const => ()
      _ => return None
    }
  }
  for
    owned_id in [
      left_id, right_id, left_multiply_left, left_multiply_right, right_multiply_left,
      right_multiply_right,
    ] {
    if @ir.hot_node_use_count(use_def, owned_id) != 1 {
      return None
    }
  }
  Some(nested_nodes)
}

///|
fn flatten_try_table_dead_suffix_deeper_two_multiply_children_nodes(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
  value_id : Int,
  left_id : Int,
  right_id : Int,
) -> Array[Int]? {
  let instr = match @ir.hot_node_exact_instr(func, value_id) {
    Some(instr) => instr
    None => return None
  }
  let rich_id = match instr {
    @lib.I32Add =>
      match
        (
          @ir.hot_node_get(func, left_id).op,
          @ir.hot_node_get(func, right_id).op,
        ) {
        (@ir.HotOp::Binary, @ir.HotOp::Const) => left_id
        _ => return None
      }
    @lib.I32Sub =>
      match
        (
          @ir.hot_node_get(func, left_id).op,
          @ir.hot_node_get(func, right_id).op,
        ) {
        (@ir.HotOp::Const, @ir.HotOp::Binary) => right_id
        _ => return None
      }
    _ => return None
  }
  if @ir.hot_node_exact_instr(func, rich_id) != Some(instr) ||
    @ir.hot_child_count(func, rich_id) != 2 {
    return None
  }
  let rich_left = @ir.hot_child_get(func, rich_id, 0)
  let rich_right = @ir.hot_child_get(func, rich_id, 1)
  for multiply_id in [rich_left, rich_right] {
    match @ir.hot_node_get(func, multiply_id).op {
      @ir.HotOp::Binary => ()
      _ => return None
    }
    if @ir.hot_node_exact_instr(func, multiply_id) !=
      Some(@lib.Instruction::i32_mul()) ||
      @ir.hot_child_count(func, multiply_id) != 2 {
      return None
    }
  }
  let left_multiply_left = @ir.hot_child_get(func, rich_left, 0)
  let left_multiply_right = @ir.hot_child_get(func, rich_left, 1)
  let right_multiply_left = @ir.hot_child_get(func, rich_right, 0)
  let right_multiply_right = @ir.hot_child_get(func, rich_right, 1)
  let nested_nodes = [
    root_id, value_id, left_id, right_id, rich_left, rich_right, left_multiply_left,
    left_multiply_right, right_multiply_left, right_multiply_right,
  ]
  for outer = 0; outer < nested_nodes.length(); outer = outer + 1 {
    for inner = outer + 1; inner < nested_nodes.length(); inner = inner + 1 {
      if nested_nodes[outer] == nested_nodes[inner] {
        return None
      }
    }
  }
  for
    leaf_id in [
      left_multiply_left, left_multiply_right, right_multiply_left, right_multiply_right,
    ] {
    match @ir.hot_node_get(func, leaf_id).op {
      @ir.HotOp::Const => ()
      _ => return None
    }
  }
  for
    owned_id in [
      left_id, right_id, rich_left, rich_right, left_multiply_left, left_multiply_right,
      right_multiply_left, right_multiply_right,
    ] {
    if @ir.hot_node_use_count(use_def, owned_id) != 1 {
      return None
    }
  }
  Some(nested_nodes)
}

///|
fn flatten_try_table_dead_suffix_collect_owned_call_argument(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  node_id : Int,
  nodes : Array[Int],
) -> Bool {
  if node_id < 0 ||
    node_id >= @ir.hot_node_count(func) ||
    !@ir.hot_node_is_live(func, node_id) ||
    nodes.contains(node_id) ||
    @ir.hot_node_result_arity(func, node_id) != 1 ||
    @ir.hot_node_use_count(use_def, node_id) != 1 {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const => {
      nodes.push(node_id)
      true
    }
    @ir.HotOp::Unary => {
      if @ir.hot_node_exact_instr(func, node_id) !=
        Some(@lib.Instruction::i32_clz()) ||
        @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      nodes.push(node_id)
      flatten_try_table_dead_suffix_collect_owned_call_argument(
        func,
        use_def,
        @ir.hot_child_get(func, node_id, 0),
        nodes,
      )
    }
    @ir.HotOp::Convert => {
      if @ir.hot_node_exact_instr(func, node_id) !=
        Some(@lib.Instruction::i64_extend_i32s()) ||
        @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      nodes.push(node_id)
      flatten_try_table_dead_suffix_collect_owned_call_argument(
        func,
        use_def,
        @ir.hot_child_get(func, node_id, 0),
        nodes,
      )
    }
    @ir.HotOp::Binary => {
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.I32Add)
        | Some(@lib.I32Sub)
        | Some(@lib.I32Mul)
        | Some(@lib.I32And)
        | Some(@lib.I32DivS) => ()
        _ => return false
      }
      if @ir.hot_child_count(func, node_id) != 2 {
        return false
      }
      nodes.push(node_id)
      flatten_try_table_dead_suffix_collect_owned_call_argument(
        func,
        use_def,
        @ir.hot_child_get(func, node_id, 0),
        nodes,
      ) &&
      flatten_try_table_dead_suffix_collect_owned_call_argument(
        func,
        use_def,
        @ir.hot_child_get(func, node_id, 1),
        nodes,
      )
    }
    _ => false
  }
}

///|
fn flatten_try_table_dead_suffix_call_argument_root_is_supported(
  func : @ir.HotFunc,
  argument_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, argument_id).op {
    @ir.HotOp::Const => true
    @ir.HotOp::Unary =>
      @ir.hot_node_exact_instr(func, argument_id) ==
      Some(@lib.Instruction::i32_clz()) &&
      @ir.hot_child_count(func, argument_id) == 1
    @ir.HotOp::Convert =>
      @ir.hot_node_exact_instr(func, argument_id) ==
      Some(@lib.Instruction::i64_extend_i32s()) &&
      @ir.hot_child_count(func, argument_id) == 1
    @ir.HotOp::Binary => {
      if @ir.hot_child_count(func, argument_id) != 2 {
        return false
      }
      match @ir.hot_node_exact_instr(func, argument_id) {
        Some(@lib.I32Add)
        | Some(@lib.I32Sub)
        | Some(@lib.I32Mul)
        | Some(@lib.I32And)
        | Some(@lib.I32Or)
        | Some(@lib.I32Xor)
        | Some(@lib.I32Shl)
        | Some(@lib.I32ShrS)
        | Some(@lib.I32ShrU)
        | Some(@lib.I32DivS) => true
        _ => false
      }
    }
    _ => false
  }
}

///|
fn flatten_try_table_dead_suffix_call_owned_argument_nodes(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  call_id : Int,
) -> Array[Int]? {
  if @ir.hot_node_result_arity(func, call_id) != 0 {
    return None
  }
  if @ir.hot_node_use_count(use_def, call_id) != 1 {
    return None
  }
  let nodes : Array[Int] = [call_id]
  for slot = 0; slot < @ir.hot_child_count(func, call_id); slot = slot + 1 {
    let argument_id = @ir.hot_child_get(func, call_id, slot)
    if argument_id < 0 ||
      argument_id >= @ir.hot_node_count(func) ||
      !@ir.hot_node_is_live(func, argument_id) ||
      nodes.contains(argument_id) ||
      @ir.hot_node_result_arity(func, argument_id) != 1 ||
      @ir.hot_node_use_count(use_def, argument_id) != 1 ||
      !flatten_try_table_dead_suffix_call_argument_root_is_supported(
        func, argument_id,
      ) {
      return None
    }
    nodes.push(argument_id)
  }
  for slot = 0; slot < @ir.hot_child_count(func, call_id); slot = slot + 1 {
    let argument_id = @ir.hot_child_get(func, call_id, slot)
    match @ir.hot_node_get(func, argument_id).op {
      @ir.HotOp::Const => ()
      @ir.HotOp::Unary | @ir.HotOp::Convert =>
        if !flatten_try_table_dead_suffix_collect_owned_call_argument(
            func,
            use_def,
            @ir.hot_child_get(func, argument_id, 0),
            nodes,
          ) {
          return None
        }
      @ir.HotOp::Binary =>
        for child_slot = 0; child_slot < 2; child_slot = child_slot + 1 {
          if !flatten_try_table_dead_suffix_collect_owned_call_argument(
              func,
              use_def,
              @ir.hot_child_get(func, argument_id, child_slot),
              nodes,
            ) {
            return None
          }
        }
      _ => return None
    }
  }
  Some(nodes)
}

///|
fn flatten_try_table_dead_suffix_root_nodes(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
) -> Array[Int]? {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Unreachable => Some([root_id])
    @ir.HotOp::Call =>
      flatten_try_table_dead_suffix_call_owned_argument_nodes(
        func, use_def, root_id,
      )
    @ir.HotOp::Drop => {
      if @ir.hot_child_count(func, root_id) != 1 {
        return None
      }
      let value_id = @ir.hot_child_get(func, root_id, 0)
      if @ir.hot_node_use_count(use_def, root_id) != 1 ||
        @ir.hot_node_use_count(use_def, value_id) != 1 {
        return None
      }
      match @ir.hot_node_get(func, value_id).op {
        @ir.HotOp::Const => Some([root_id, value_id])
        @ir.HotOp::Unary => {
          match @ir.hot_node_exact_instr(func, value_id) {
            Some(@lib.I32Clz) => ()
            _ => return None
          }
          if @ir.hot_child_count(func, value_id) != 1 {
            return None
          }
          let input_id = @ir.hot_child_get(func, value_id, 0)
          if @ir.hot_node_result_arity(func, input_id) != 1 ||
            @ir.hot_node_use_count(use_def, input_id) != 1 {
            return None
          }
          match @ir.hot_node_get(func, input_id).op {
            @ir.HotOp::Const => Some([root_id, value_id, input_id])
            _ => None
          }
        }
        @ir.HotOp::Convert => {
          match @ir.hot_node_exact_instr(func, value_id) {
            Some(@lib.I64ExtendI32S) => ()
            _ => return None
          }
          if @ir.hot_child_count(func, value_id) != 1 {
            return None
          }
          let input_id = @ir.hot_child_get(func, value_id, 0)
          if @ir.hot_node_result_arity(func, input_id) != 1 ||
            @ir.hot_node_use_count(use_def, input_id) != 1 {
            return None
          }
          match @ir.hot_node_get(func, input_id).op {
            @ir.HotOp::Const => Some([root_id, value_id, input_id])
            _ => None
          }
        }
        @ir.HotOp::Binary => {
          let instr = match @ir.hot_node_exact_instr(func, value_id) {
            Some(instr) => instr
            None => return None
          }
          if @ir.hot_child_count(func, value_id) != 2 {
            return None
          }
          let left_id = @ir.hot_child_get(func, value_id, 0)
          let right_id = @ir.hot_child_get(func, value_id, 1)
          if left_id == right_id {
            return None
          }
          match instr {
            @lib.I32Add | @lib.I32Sub => {
              match
                flatten_try_table_dead_suffix_deeper_two_multiply_children_nodes(
                  func, use_def, root_id, value_id, left_id, right_id,
                ) {
                Some(nodes) => return Some(nodes)
                None => ()
              }
              match
                flatten_try_table_dead_suffix_two_multiply_children_nodes(
                  func, use_def, root_id, value_id, left_id, right_id,
                ) {
                Some(nodes) => return Some(nodes)
                None => ()
              }
            }
            _ => ()
          }
          match instr {
            @lib.I32Sub => {
              match
                flatten_try_table_dead_suffix_subtract_one_multiply_child_nodes(
                  func, use_def, root_id, value_id, left_id, right_id, true,
                ) {
                Some(nodes) => return Some(nodes)
                None => ()
              }
              match
                flatten_try_table_dead_suffix_subtract_one_multiply_child_nodes(
                  func, use_def, root_id, value_id, left_id, right_id, false,
                ) {
                Some(nodes) => return Some(nodes)
                None => ()
              }
            }
            _ => ()
          }
          match instr {
            @lib.I32Add => {
              let multiply_id = match
                (
                  @ir.hot_node_get(func, left_id).op,
                  @ir.hot_node_get(func, right_id).op,
                ) {
                (@ir.HotOp::Const, @ir.HotOp::Binary) => right_id
                (@ir.HotOp::Binary, @ir.HotOp::Const) => left_id
                _ => -1
              }
              if multiply_id >= 0 &&
                @ir.hot_node_exact_instr(func, multiply_id) ==
                Some(@lib.Instruction::i32_mul()) &&
                @ir.hot_child_count(func, multiply_id) == 2 {
                let multiply_left = @ir.hot_child_get(func, multiply_id, 0)
                let multiply_right = @ir.hot_child_get(func, multiply_id, 1)
                let nested_nodes = [
                  root_id, value_id, left_id, right_id, multiply_left, multiply_right,
                ]
                for outer = 0; outer < nested_nodes.length(); outer = outer + 1 {
                  for inner = outer + 1
                      inner < nested_nodes.length()
                      inner = inner + 1 {
                    if nested_nodes[outer] == nested_nodes[inner] {
                      return None
                    }
                  }
                }
                match
                  (
                    @ir.hot_node_get(func, multiply_left).op,
                    @ir.hot_node_get(func, multiply_right).op,
                  ) {
                  (@ir.HotOp::Const, @ir.HotOp::Const) => ()
                  _ => return None
                }
                if @ir.hot_node_use_count(use_def, left_id) != 1 ||
                  @ir.hot_node_use_count(use_def, right_id) != 1 ||
                  @ir.hot_node_use_count(use_def, multiply_left) != 1 ||
                  @ir.hot_node_use_count(use_def, multiply_right) != 1 {
                  return None
                }
                return Some(nested_nodes)
              }
            }
            _ => ()
          }
          match instr {
            @lib.I32DivS => ()
            @lib.I32Add => ()
            @lib.I32Sub => ()
            @lib.I32Mul => ()
            @lib.I32And => ()
            _ => return None
          }
          match
            (
              @ir.hot_node_get(func, left_id).op,
              @ir.hot_node_get(func, right_id).op,
            ) {
            (@ir.HotOp::Const, @ir.HotOp::Const) => ()
            _ => return None
          }
          if @ir.hot_node_use_count(use_def, left_id) != 1 ||
            @ir.hot_node_use_count(use_def, right_id) != 1 {
            return None
          }
          Some([root_id, value_id, left_id, right_id])
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn flatten_try_table_dead_suffix_root_is_direct_drop_const(
  func : @ir.HotFunc,
  root_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, root_id, 0)).op {
    @ir.HotOp::Const => true
    _ => false
  }
}

///|
fn flatten_try_table_dead_suffix_root_direct_i32_binary_instr(
  func : @ir.HotFunc,
  root_id : Int,
) -> @lib.Instruction? {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Drop => ()
    _ => return None
  }
  if @ir.hot_child_count(func, root_id) != 1 {
    return None
  }
  let binary_id = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, binary_id).op {
    @ir.HotOp::Binary => ()
    _ => return None
  }
  let instr = match @ir.hot_node_exact_instr(func, binary_id) {
    Some(instr) =>
      match instr {
        @lib.I32Add | @lib.I32Sub | @lib.I32Mul | @lib.I32And | @lib.I32DivS =>
          instr
        _ => return None
      }
    None => return None
  }
  if @ir.hot_child_count(func, binary_id) != 2 {
    return None
  }
  let left_id = @ir.hot_child_get(func, binary_id, 0)
  let right_id = @ir.hot_child_get(func, binary_id, 1)
  if left_id == right_id {
    return None
  }
  match
    (@ir.hot_node_get(func, left_id).op, @ir.hot_node_get(func, right_id).op) {
    (@ir.HotOp::Const, @ir.HotOp::Const) => Some(instr)
    _ => None
  }
}

///|
fn flatten_try_table_dead_suffix_root_is_one_multiply_child_drop(
  func : @ir.HotFunc,
  root_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  let outer_id = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, outer_id).op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  match @ir.hot_node_exact_instr(func, outer_id) {
    Some(@lib.I32Add) | Some(@lib.I32Sub) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, outer_id) != 2 {
    return false
  }
  let left_id = @ir.hot_child_get(func, outer_id, 0)
  let right_id = @ir.hot_child_get(func, outer_id, 1)
  let multiply_id = match
    (@ir.hot_node_get(func, left_id).op, @ir.hot_node_get(func, right_id).op) {
    (@ir.HotOp::Binary, @ir.HotOp::Const) => left_id
    (@ir.HotOp::Const, @ir.HotOp::Binary) => right_id
    _ => return false
  }
  if @ir.hot_node_exact_instr(func, multiply_id) !=
    Some(@lib.Instruction::i32_mul()) ||
    @ir.hot_child_count(func, multiply_id) != 2 {
    return false
  }
  match
    (
      @ir.hot_node_get(func, @ir.hot_child_get(func, multiply_id, 0)).op,
      @ir.hot_node_get(func, @ir.hot_child_get(func, multiply_id, 1)).op,
    ) {
    (@ir.HotOp::Const, @ir.HotOp::Const) => true
    _ => false
  }
}

///|
fn flatten_try_table_dead_suffix_root_is_deeper_two_multiply_children_drop(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  let value_id = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if @ir.hot_child_count(func, value_id) != 2 {
    return false
  }
  flatten_try_table_dead_suffix_deeper_two_multiply_children_nodes(
    func,
    use_def,
    root_id,
    value_id,
    @ir.hot_child_get(func, value_id, 0),
    @ir.hot_child_get(func, value_id, 1),
  )
  is Some(_)
}

///|
fn flatten_try_table_dead_suffix_root_is_two_multiply_children_drop(
  func : @ir.HotFunc,
  root_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  let outer_id = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, outer_id).op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  match @ir.hot_node_exact_instr(func, outer_id) {
    Some(@lib.I32Add) | Some(@lib.I32Sub) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, outer_id) != 2 {
    return false
  }
  let left_id = @ir.hot_child_get(func, outer_id, 0)
  let right_id = @ir.hot_child_get(func, outer_id, 1)
  if left_id == right_id {
    return false
  }
  for multiply_id in [left_id, right_id] {
    match @ir.hot_node_get(func, multiply_id).op {
      @ir.HotOp::Binary => ()
      _ => return false
    }
    if @ir.hot_node_exact_instr(func, multiply_id) !=
      Some(@lib.Instruction::i32_mul()) ||
      @ir.hot_child_count(func, multiply_id) != 2 {
      return false
    }
    let multiply_left = @ir.hot_child_get(func, multiply_id, 0)
    let multiply_right = @ir.hot_child_get(func, multiply_id, 1)
    if multiply_left == multiply_right {
      return false
    }
    match
      (
        @ir.hot_node_get(func, multiply_left).op,
        @ir.hot_node_get(func, multiply_right).op,
      ) {
      (@ir.HotOp::Const, @ir.HotOp::Const) => ()
      _ => return false
    }
  }
  true
}

///|
fn flatten_try_table_dead_suffix_root_is_direct_sequence_member(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
) -> Bool {
  if flatten_try_table_dead_suffix_root_is_direct_drop_const(func, root_id) ||
    flatten_try_table_dead_suffix_root_direct_i32_binary_instr(func, root_id)
    is Some(_) ||
    flatten_try_table_dead_suffix_root_is_one_multiply_child_drop(func, root_id) ||
    flatten_try_table_dead_suffix_root_is_deeper_two_multiply_children_drop(
      func, use_def, root_id,
    ) ||
    flatten_try_table_dead_suffix_root_is_two_multiply_children_drop(
      func, root_id,
    ) {
    return true
  }
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Unreachable => return true
    @ir.HotOp::Call =>
      return flatten_try_table_dead_suffix_call_owned_argument_nodes(
          func, use_def, root_id,
        )
        is Some(_)
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  let value_id = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Unary =>
      if @ir.hot_node_exact_instr(func, value_id) !=
        Some(@lib.Instruction::i32_clz()) {
        return false
      }
    @ir.HotOp::Convert =>
      if @ir.hot_node_exact_instr(func, value_id) !=
        Some(@lib.Instruction::i64_extend_i32s()) {
        return false
      }
    _ => return false
  }
  if @ir.hot_child_count(func, value_id) != 1 {
    return false
  }
  match @ir.hot_node_get(func, @ir.hot_child_get(func, value_id, 0)).op {
    @ir.HotOp::Const => true
    _ => false
  }
}

///|
fn flatten_try_table_dead_suffix_nodes(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  table_id : Int,
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  match state {
    Some(state) => {
      let entry_index = flatten_dead_suffix_entry_index(
        state.dead_suffix_entries,
        table_id,
      )
      if entry_index >= 0 {
        let entry = state.dead_suffix_entries[entry_index]
        if entry.region_ref == region_ref {
          return Some(entry.nodes)
        }
        return None
      }
      if state.rewrites_started {
        return None
      }
    }
    None => ()
  }
  let nodes : Array[Int] = []
  let root_count = @ir.hot_region_root_count(func, region_ref)
  for root_idx = 0; root_idx < root_count; root_idx = root_idx + 1 {
    if @ir.hot_region_get(func, region_ref, root_idx) != table_id {
      continue
    }
    let suffix_count = root_count - root_idx - 1
    let use_def = match state {
      Some(state) => state.use_def
      None => flatten_build_node_use_counts(func)
    }
    let recognized_suffix_roots : Array[Array[Int]?] = []
    if suffix_count > 1 {
      let mut all_unreachable = true
      let mut all_direct_drop_consts = true
      let mut exact_drop_const_then_unreachable = suffix_count == 2
      let mut exact_unreachable_then_drop_const = suffix_count == 2
      let mut exact_add_drop_then_unreachable = suffix_count == 2
      let mut exact_unreachable_then_add_drop = suffix_count == 2
      let mut all_direct_sequence_roots = true
      for suffix_idx = root_idx + 1
          suffix_idx < root_count
          suffix_idx = suffix_idx + 1 {
        let root_id = @ir.hot_region_get(func, region_ref, suffix_idx)
        let recognized_root = flatten_try_table_dead_suffix_root_nodes(
          func, use_def, root_id,
        )
        recognized_suffix_roots.push(recognized_root)
        let root_is_unreachable = match @ir.hot_node_get(func, root_id).op {
          @ir.HotOp::Unreachable => true
          _ => false
        }
        if !root_is_unreachable {
          all_unreachable = false
        }
        let root_is_direct_drop_const = flatten_try_table_dead_suffix_root_is_direct_drop_const(
          func, root_id,
        )
        if !root_is_direct_drop_const {
          all_direct_drop_consts = false
        }
        let direct_binary_instr = flatten_try_table_dead_suffix_root_direct_i32_binary_instr(
          func, root_id,
        )
        let root_is_direct_add = direct_binary_instr ==
          Some(@lib.Instruction::i32_add())
        let root_is_direct_sequence = match @ir.hot_node_get(func, root_id).op {
          @ir.HotOp::Call => recognized_root is Some(_)
          _ =>
            flatten_try_table_dead_suffix_root_is_direct_sequence_member(
              func, use_def, root_id,
            )
        }
        if !root_is_direct_sequence {
          all_direct_sequence_roots = false
        }
        if suffix_idx == root_idx + 1 {
          if !root_is_direct_drop_const {
            exact_drop_const_then_unreachable = false
          }
          if !root_is_unreachable {
            exact_unreachable_then_drop_const = false
            exact_unreachable_then_add_drop = false
          }
          if !root_is_direct_add {
            exact_add_drop_then_unreachable = false
          }
        } else {
          if !root_is_unreachable {
            exact_drop_const_then_unreachable = false
            exact_add_drop_then_unreachable = false
          }
          if !root_is_direct_drop_const {
            exact_unreachable_then_drop_const = false
          }
          if !root_is_direct_add {
            exact_unreachable_then_add_drop = false
          }
        }
      }
      if !all_unreachable &&
        !all_direct_drop_consts &&
        !exact_drop_const_then_unreachable &&
        !exact_unreachable_then_drop_const &&
        !exact_add_drop_then_unreachable &&
        !exact_unreachable_then_add_drop &&
        !all_direct_sequence_roots {
        return None
      }
    }
    for suffix_idx = root_idx + 1
        suffix_idx < root_count
        suffix_idx = suffix_idx + 1 {
      let root_id = @ir.hot_region_get(func, region_ref, suffix_idx)
      let recognized_root = if suffix_count > 1 {
        recognized_suffix_roots[suffix_idx - root_idx - 1]
      } else {
        flatten_try_table_dead_suffix_root_nodes(func, use_def, root_id)
      }
      let root_nodes = match recognized_root {
        Some(root_nodes) => root_nodes
        None => return None
      }
      for node_id in root_nodes {
        if nodes.contains(node_id) {
          return None
        }
        nodes.push(node_id)
      }
    }
    match state {
      Some(state) =>
        state.dead_suffix_entries.push(
          FlattenDeadSuffixEntry::new(table_id, region_ref, nodes),
        )
      None => ()
    }
    return Some(nodes)
  }
  None
}

///|
fn flatten_try_terminal_br_table_targets_label(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  payload_count : Int,
  allow_mixed_targets : Bool,
  state? : FlattenRewriteState? = None,
) -> Bool {
  if node_id < 0 || node_id >= @ir.hot_node_count(func) {
    return false
  }
  match state {
    Some(state) => {
      let entry_index = flatten_terminal_table_entry_index(
        state.terminal_table_entries,
        node_id,
      )
      if entry_index >= 0 {
        let entry = state.terminal_table_entries[entry_index]
        return entry.label_id == label_id &&
          entry.payload_count == payload_count &&
          entry.allow_mixed_targets == allow_mixed_targets &&
          entry.supported
      }
      if state.rewrites_started {
        return false
      }
    }
    None => ()
  }
  let supported = flatten_try_terminal_br_table_targets_label_uncached(
    func,
    node_id,
    label_id,
    payload_count,
    allow_mixed_targets,
    state~,
  )
  match state {
    Some(state) =>
      state.terminal_table_entries.push(
        FlattenTerminalTableEntry::new(
          node_id, label_id, payload_count, allow_mixed_targets, supported,
        ),
      )
    None => ()
  }
  supported
}

///|
fn flatten_try_terminal_br_table_targets_label_uncached(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  payload_count : Int,
  allow_mixed_targets : Bool,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::BrTable => ()
    _ => return false
  }
  let targets = flatten_unique_br_table_targets(func, node.imm0)
  if !targets.contains(label_id) ||
    (!allow_mixed_targets && targets.length() != 1) {
    return false
  }
  let try_id = @ir.hot_label_owner(func, label_id)
  match @ir.hot_node_get(func, try_id).op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  let target_controls : Array[Int] = []
  for target in targets {
    if target == label_id {
      continue
    }
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::BlockLabel
      | @ir.HotLabelKind::IfLabel
      | @ir.HotLabelKind::LoopLabel =>
        target_controls.push(@ir.hot_label_owner(func, target))
      _ => return false
    }
  }
  match
    flatten_direct_enclosing_target_controls(func, try_id, target_controls) {
    Some(_) => ()
    None => return false
  }
  let catch_ref = match @ir.hot_region_catch_ref(func, try_id) {
    Some(catch_ref) => catch_ref
    None => return false
  }
  let mut is_terminal = false
  for region_ref in [@ir.hot_region_body_ref(func, try_id), catch_ref] {
    if flatten_try_table_dead_suffix_nodes(func, region_ref, node_id, state~)
      is Some(_) {
      is_terminal = true
    }
  }
  if !is_terminal {
    return false
  }
  let child_count = @ir.hot_child_count(func, node_id)
  child_count == 1 || child_count == payload_count + 1
}

///|
fn flatten_try_region_effective_terminal_id(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  state? : FlattenRewriteState? = None,
) -> Int {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return -1
  }
  let last_id = @ir.hot_region_get(func, region_ref, root_count - 1)
  for root_idx = 0; root_idx < root_count; root_idx = root_idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, root_idx)
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::BrTable =>
        if flatten_try_table_dead_suffix_nodes(
            func,
            region_ref,
            node_id,
            state~,
          )
          is Some(_) {
          return node_id
        }
      _ => ()
    }
  }
  last_id
}

///|
fn flatten_multivalue_try_terminal_br_table_targets_label(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  payload_count : Int,
  allow_mixed_targets : Bool,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::BrTable => ()
    _ => return false
  }
  flatten_try_terminal_br_table_targets_label(
    func,
    node_id,
    label_id,
    payload_count,
    allow_mixed_targets,
    state~,
  )
}

///|
fn flatten_multivalue_try_br_if_flow_is_exact(
  func : @ir.HotFunc,
  try_id : Int,
  branch_id : Int,
  result_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  let payload_count = result_types.length()
  let branch = @ir.hot_node_get(func, branch_id)
  if payload_count <= 1 ||
    branch.imm0 != @ir.hot_control_node_label(func, try_id) ||
    @ir.hot_child_count(func, branch_id) != payload_count + 1 {
    return None
  }
  match branch.op {
    @ir.HotOp::BrIf => ()
    _ => return None
  }
  let first_payload = @ir.hot_child_get(func, branch_id, 0)
  let mut tuple_id = first_payload
  for slot = 1; slot < payload_count; slot = slot + 1 {
    if @ir.hot_child_get(func, branch_id, slot) != tuple_id {
      tuple_id = -1
    }
  }
  if tuple_id >= 0 {
    let tuple = @ir.hot_node_get(func, tuple_id)
    match tuple.op {
      @ir.HotOp::TupleMake => ()
      _ => tuple_id = -1
    }
    if tuple_id >= 0 &&
      (
        @ir.hot_type_results(func, tuple.ty) != result_types ||
        @ir.hot_child_count(func, tuple_id) != payload_count
      ) {
      return None
    }
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if tuple_id >= 0 {
    if @ir.hot_node_use_count(use_counts, tuple_id) != payload_count * 2 {
      return None
    }
    for slot = 0; slot < payload_count; slot = slot + 1 {
      let value_id = @ir.hot_child_get(func, tuple_id, slot)
      let value_types = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, value_id).ty,
      )
      if value_types.length() != 1 ||
        value_types[0] != result_types[slot] ||
        !flatten_value_type_is_defaultable(result_types[slot]) ||
        !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
        return None
      }
    }
  } else {
    let payloads : Array[Int] = []
    for slot = 0; slot < payload_count; slot = slot + 1 {
      let payload_id = @ir.hot_child_get(func, branch_id, slot)
      if payloads.contains(payload_id) ||
        @ir.hot_node_use_count(use_counts, payload_id) != 2 {
        return None
      }
      payloads.push(payload_id)
      let payload_types = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, payload_id).ty,
      )
      if payload_types.length() != 1 ||
        payload_types[0] != result_types[slot] ||
        !flatten_value_type_is_defaultable(result_types[slot]) ||
        !flatten_scalar_branch_payload_has_supported_origin(func, payload_id) {
        return None
      }
    }
  }
  let catch_ref = match @ir.hot_region_catch_ref(func, try_id) {
    Some(catch_ref) => catch_ref
    None => return None
  }
  let regions = [@ir.hot_region_body_ref(func, try_id), catch_ref]
  for arm = 0; arm < regions.length(); arm = arm + 1 {
    let region_ref = regions[arm]
    let root_count = @ir.hot_region_root_count(func, region_ref)
    for root_idx = 0
        root_idx + payload_count < root_count
        root_idx = root_idx + 1 {
      if @ir.hot_region_get(func, region_ref, root_idx) != branch_id {
        continue
      }
      for offset = 0; offset < payload_count; offset = offset + 1 {
        let consumer_id = @ir.hot_region_get(
          func,
          region_ref,
          root_idx + 1 + offset,
        )
        let expected_payload = if tuple_id >= 0 {
          tuple_id
        } else {
          @ir.hot_child_get(func, branch_id, payload_count - 1 - offset)
        }
        if tuple_id >= 0 {
          if !flatten_multivalue_tuple_br_if_consumer_matches_lane(
              func,
              use_counts,
              consumer_id,
              tuple_id,
              result_types[payload_count - 1 - offset],
            ) {
            return None
          }
        } else if !flatten_multivalue_loop_br_if_consumer_matches_payload(
            func, use_counts, consumer_id, expected_payload,
          ) {
          return None
        }
      }
      return Some([tuple_id, arm, root_idx])
    }
  }
  None
}

///|
fn flatten_rewrite_multivalue_try_br_if_flow_is_exact(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  try_id : Int,
  branch_id : Int,
  result_types : Array[@lib.ValType],
) -> Array[Int]? {
  if !state.rewrites_started {
    return None
  }
  flatten_multivalue_try_br_if_flow_is_exact(
    func,
    try_id,
    branch_id,
    result_types,
    state=Some(state),
  )
}

///|
fn flatten_multivalue_legacy_try_label_uses_are_supported(
  func : @ir.HotFunc,
  try_id : Int,
  result_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Bool {
  let label_id = @ir.hot_control_node_label(func, try_id)
  let mut saw_target = false
  let branch_nodes = match state {
    Some(state) => state.label_branch_nodes[label_id]
    None => flatten_build_label_branch_nodes(func)[label_id]
  }
  for node_id in branch_nodes {
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br if node.imm0 == label_id => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count == 0 {
          continue
        }
        if child_count != result_types.length() {
          return false
        }
        if flatten_multivalue_tuple_branch_payload_values(
            func,
            node_id,
            child_count,
            result_types,
            state~,
          )
          is Some(_) {
          continue
        }
        for slot = 0; slot < child_count; slot = slot + 1 {
          let payload_id = @ir.hot_child_get(func, node_id, slot)
          let payload_types = @ir.hot_type_results(
            func,
            @ir.hot_node_get(func, payload_id).ty,
          )
          if payload_types.length() != 1 ||
            payload_types[0] != result_types[slot] ||
            !flatten_value_type_is_defaultable(result_types[slot]) ||
            !flatten_scalar_branch_payload_has_supported_origin(
              func, payload_id,
            ) {
            return false
          }
        }
      }
      @ir.HotOp::BrIf if node.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) == 1 {
          continue
        }
        if flatten_multivalue_try_br_if_flow_is_exact(
            func,
            try_id,
            node_id,
            result_types,
            state~,
          )
          is None {
          return false
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if node.imm0 == label_id => return false
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          node.imm0,
          label_id,
        ) => {
        saw_target = true
        if !flatten_multivalue_try_terminal_br_table_targets_label(
            func,
            node_id,
            label_id,
            result_types.length(),
            true,
            state~,
          ) {
          return false
        }
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count == 1 {
          continue
        }
        if flatten_multivalue_tuple_branch_payload_values(
            func,
            node_id,
            result_types.length(),
            result_types,
            state~,
          )
          is Some(_) {
          continue
        }
        for slot = 0; slot < result_types.length(); slot = slot + 1 {
          let payload_id = @ir.hot_child_get(func, node_id, slot)
          let payload_types = @ir.hot_type_results(
            func,
            @ir.hot_node_get(func, payload_id).ty,
          )
          if payload_types.length() != 1 ||
            payload_types[0] != result_types[slot] ||
            !flatten_value_type_is_defaultable(result_types[slot]) ||
            !flatten_scalar_branch_payload_has_supported_origin(
              func, payload_id,
            ) {
            return false
          }
        }
      }
      _ => ()
    }
  }
  saw_target
}

///|
fn flatten_multivalue_legacy_try_is_supported(
  func : @ir.HotFunc,
  try_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let try_node = @ir.hot_node_get(func, try_id)
  match try_node.op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  let result_types = @ir.hot_type_results(func, try_node.ty)
  if result_types.length() <= 1 ||
    flatten_legacy_try_has_deferred_eh_repair(func, state~) ||
    (
      !flatten_multivalue_control_has_exclusive_consumer_span(func, try_id) &&
      !flatten_multivalue_control_has_exclusive_region_tail_span(func, try_id)
    ) {
    return false
  }
  for result_type in result_types {
    if !flatten_value_type_is_defaultable(result_type) {
      return false
    }
  }
  let label_id = @ir.hot_control_node_label(func, try_id)
  let label_is_used = flatten_cached_label_is_used(func, label_id, state~)
  if label_is_used &&
    !flatten_multivalue_legacy_try_label_uses_are_supported(
      func,
      try_id,
      result_types,
      state~,
    ) {
    return false
  }
  let catch_ref = match @ir.hot_region_catch_ref(func, try_id) {
    Some(catch_ref) => catch_ref
    None => return false
  }
  let regions = [@ir.hot_region_body_ref(func, try_id), catch_ref]
  for region_ref in regions {
    let root_count = @ir.hot_region_root_count(func, region_ref)
    if root_count == 0 {
      return false
    }
    let tail_id = flatten_try_region_effective_terminal_id(
      func,
      region_ref,
      state~,
    )
    if label_is_used &&
      (
        flatten_multivalue_try_terminal_plain_br_targets_label(
          func,
          tail_id,
          label_id,
          result_types.length(),
        ) ||
        flatten_multivalue_try_terminal_br_table_targets_label(
          func,
          tail_id,
          label_id,
          result_types.length(),
          true,
          state~,
        )
      ) {
      continue
    }
    if flatten_multivalue_region_tail_matches_types(
        func, region_ref, result_types,
      ) {
      continue
    }
    if flatten_multivalue_region_tail_tuple_make_has_supported_origins(
        func,
        region_ref,
        result_types,
        state~,
      ) {
      continue
    }
    return false
  }
  true
}

///|
fn flatten_try_route_multivalue_try(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  try_id : Int,
) -> Array[Int]? {
  if !flatten_multivalue_legacy_try_is_supported(
      func,
      try_id,
      state=Some(state),
    ) {
    return None
  }
  let result_types = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, try_id).ty,
  )
  let label_id = @ir.hot_control_node_label(func, try_id)
  let locals = match
    flatten_ensure_label_temps(func, state, label_id, result_types) {
    Some(locals) => locals
    None => return None
  }
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  for region_ref in [@ir.hot_region_body_ref(func, try_id), catch_ref] {
    let tail_id = @ir.hot_region_get(
      func,
      region_ref,
      @ir.hot_region_root_count(func, region_ref) - 1,
    )
    if flatten_multivalue_try_terminal_plain_br_targets_label(
        func,
        tail_id,
        label_id,
        result_types.length(),
      ) ||
      flatten_multivalue_try_terminal_br_table_targets_label(
        func,
        tail_id,
        label_id,
        result_types.length(),
        true,
      ) {
      continue
    }
    match
      flatten_rewrite_multivalue_region_tail_tuple_make_values(
        func, state, region_ref, result_types,
      ) {
      Some(values) =>
        flatten_replace_multivalue_tuple_make_tail(
          ctx, func, region_ref, values, locals,
        )
      None => {
        let tail_start = @ir.hot_region_root_count(func, region_ref) -
          result_types.length()
        for slot = 0; slot < result_types.length(); slot = slot + 1 {
          let value_id = @ir.hot_region_get(func, region_ref, tail_start + slot)
          ignore(
            flatten_set_region_root(
              ctx,
              func,
              region_ref,
              tail_start + slot,
              @ir.hot_build_local_set(func, locals[slot], value_id),
            ),
          )
        }
      }
    }
  }
  @ir.hot_control_result_type_set(func, try_id, @ir.hot_type_void(func))
  Some(locals)
}

///|
fn flatten_try_route_payloadless_multivalue_loop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  loop_id : Int,
) -> Array[Int]? {
  let loop_node = @ir.hot_node_get(func, loop_id)
  match loop_node.op {
    @ir.HotOp::Loop => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, loop_node.ty)
  if result_types.length() <= 1 {
    return None
  }
  for result_type in result_types {
    if !flatten_value_type_is_defaultable(result_type) {
      return None
    }
  }
  let label_id = @ir.hot_control_node_label(func, loop_id)
  if @ir.hot_label_branch_arity(func, label_id) != 0 ||
    !flatten_loop_label_uses_are_payloadless(func, label_id) {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  let tuple_values = flatten_rewrite_multivalue_region_tail_tuple_make_values(
    func, state, body_ref, result_types,
  )
  if !flatten_multivalue_region_tail_matches_types(func, body_ref, result_types) &&
    tuple_values is None {
    return None
  }
  let locals = if state.label_temps[label_id].length() > 0 {
    let result_locals : Array[Int] = []
    for result_type in result_types {
      result_locals.push(@ir.hot_append_body_local(func, result_type))
    }
    result_locals
  } else {
    match flatten_ensure_label_temps(func, state, label_id, result_types) {
      Some(locals) => locals
      None => return None
    }
  }
  match tuple_values {
    Some(values) =>
      flatten_replace_multivalue_tuple_make_tail(
        ctx, func, body_ref, values, locals,
      )
    None => {
      let tail_start = body_count - result_types.length()
      for slot = 0; slot < result_types.length(); slot = slot + 1 {
        let value_id = @ir.hot_region_get(func, body_ref, tail_start + slot)
        ignore(
          flatten_set_region_root(
            ctx,
            func,
            body_ref,
            tail_start + slot,
            @ir.hot_build_local_set(func, locals[slot], value_id),
          ),
        )
      }
    }
  }
  @ir.hot_control_result_type_set(func, loop_id, @ir.hot_type_void(func))
  Some(locals)
}

///|
fn flatten_multivalue_control_use_span_is_exclusive(
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  result_count : Int,
) -> Bool {
  if slot + result_count > @ir.hot_child_count(func, parent_id) {
    return false
  }
  for result_slot = 0; result_slot < result_count; result_slot = result_slot + 1 {
    if @ir.hot_child_get(func, parent_id, slot + result_slot) != child_id {
      return false
    }
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    for child_slot = 0
        child_slot < @ir.hot_child_count(func, node_id)
        child_slot = child_slot + 1 {
      if @ir.hot_child_get(func, node_id, child_slot) == child_id &&
        (
          node_id != parent_id ||
          child_slot < slot ||
          child_slot >= slot + result_count
        ) {
        return false
      }
    }
  }
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    if @ir.hot_root_get(func, root_idx) == child_id {
      return false
    }
  }
  true
}

///|
fn flatten_multivalue_control_has_exclusive_consumer_span(
  func : @ir.HotFunc,
  child_id : Int,
) -> Bool {
  let result_count = @ir.hot_node_result_arity(func, child_id)
  if result_count <= 1 {
    return false
  }
  for parent_id = 0
      parent_id < @ir.hot_node_count(func)
      parent_id = parent_id + 1 {
    if !@ir.hot_node_is_live(func, parent_id) {
      continue
    }
    for slot = 0; slot < @ir.hot_child_count(func, parent_id); slot = slot + 1 {
      if @ir.hot_child_get(func, parent_id, slot) == child_id {
        return flatten_multivalue_control_use_span_is_exclusive(
          func, parent_id, slot, child_id, result_count,
        )
      }
    }
  }
  false
}

///|
fn flatten_multivalue_region_control_ownership(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  child_id : Int,
  result_count : Int,
) -> Array[Int] {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut use_count = 0
  for idx = 0; idx < root_count; idx = idx + 1 {
    if @ir.hot_region_get(func, region_ref, idx) == child_id {
      use_count = use_count + 1
    }
  }
  if use_count != result_count || root_count < result_count {
    return [use_count, 0]
  }
  let tail_start = root_count - result_count
  for slot = 0; slot < result_count; slot = slot + 1 {
    if @ir.hot_region_get(func, region_ref, tail_start + slot) != child_id {
      return [use_count, 0]
    }
  }
  [use_count, 1]
}

///|
fn flatten_multivalue_control_has_exclusive_region_tail_span(
  func : @ir.HotFunc,
  child_id : Int,
) -> Bool {
  let result_count = @ir.hot_node_result_arity(func, child_id)
  if result_count <= 1 {
    return false
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    for slot = 0
        slot < flatten_operand_slot_count(func, node_id)
        slot = slot + 1 {
      if @ir.hot_child_get(func, node_id, slot) == child_id {
        return false
      }
    }
  }
  let mut total_uses = 0
  let mut tail_spans = 0
  let root_ownership = flatten_multivalue_region_control_ownership(
    func,
    @ir.HotRegionRef::root(),
    child_id,
    result_count,
  )
  total_uses = total_uses + root_ownership[0]
  tail_spans = tail_spans + root_ownership[1]
  for holder_id = 0
      holder_id < @ir.hot_node_count(func)
      holder_id = holder_id + 1 {
    if !@ir.hot_node_is_live(func, holder_id) {
      continue
    }
    match @ir.hot_node_get(func, holder_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop => ()
      _ => continue
    }
    let ownership = flatten_multivalue_region_control_ownership(
      func,
      @ir.hot_region_body_ref(func, holder_id),
      child_id,
      result_count,
    )
    total_uses = total_uses + ownership[0]
    tail_spans = tail_spans + ownership[1]
  }
  total_uses == result_count && tail_spans == 1
}

///|
fn flatten_try_route_multivalue_control_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  preludes : Array[Int],
) -> Bool {
  let result_count = @ir.hot_node_result_arity(func, child_id)
  if result_count <= 1 ||
    !flatten_multivalue_control_use_span_is_exclusive(
      func, parent_id, slot, child_id, result_count,
    ) {
    return false
  }
  let locals = match @ir.hot_node_get(func, child_id).op {
    @ir.HotOp::Block =>
      flatten_try_route_multivalue_block(ctx, func, state, child_id)
    @ir.HotOp::If => flatten_try_route_multivalue_if(ctx, func, state, child_id)
    @ir.HotOp::Loop =>
      flatten_try_route_payloadless_multivalue_loop(ctx, func, state, child_id)
    @ir.HotOp::Try =>
      flatten_try_route_multivalue_try(ctx, func, state, child_id)
    _ => None
  }
  let locals = match locals {
    Some(locals) => locals
    None => return false
  }
  preludes.push(child_id)
  for result_slot = 0; result_slot < result_count; result_slot = result_slot + 1 {
    @ir.hot_child_set(
      func,
      parent_id,
      slot + result_slot,
      @ir.hot_build_local_get(func, locals[result_slot]),
    )
  }
  true
}

///|
fn flatten_try_route_multivalue_control_region_span(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  region_ref : @ir.HotRegionRef,
  root_idx : Int,
  child_id : Int,
) -> Int? {
  let result_count = @ir.hot_node_result_arity(func, child_id)
  if result_count <= 1 ||
    root_idx + result_count > @ir.hot_region_root_count(func, region_ref) ||
    !flatten_multivalue_control_has_exclusive_region_tail_span(func, child_id) {
    return None
  }
  for slot = 0; slot < result_count; slot = slot + 1 {
    if @ir.hot_region_get(func, region_ref, root_idx + slot) != child_id {
      return None
    }
  }
  let locals = match @ir.hot_node_get(func, child_id).op {
    @ir.HotOp::Block =>
      flatten_try_route_multivalue_block(ctx, func, state, child_id)
    @ir.HotOp::If => flatten_try_route_multivalue_if(ctx, func, state, child_id)
    @ir.HotOp::Loop =>
      flatten_try_route_payloadless_multivalue_loop(ctx, func, state, child_id)
    @ir.HotOp::Try =>
      flatten_try_route_multivalue_try(ctx, func, state, child_id)
    _ => None
  }
  let locals = match locals {
    Some(locals) => locals
    None => return None
  }
  let replacement = [child_id]
  for local_id in locals {
    replacement.push(@ir.hot_build_local_get(func, local_id))
  }
  ignore(
    pass_splice_region(
      ctx, func, region_ref, root_idx, result_count, replacement,
    ),
  )
  Some(result_count + 1)
}

///|
fn flatten_try_route_scalar_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  block_id : Int,
) -> Int? {
  let block = @ir.hot_node_get(func, block_id)
  match block.op {
    @ir.HotOp::Block => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, block.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return None
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  let label_is_used = flatten_cached_label_is_used(
    func,
    label_id,
    state=Some(state),
  )
  let routed_local = if label_is_used {
    if label_id < 0 ||
      label_id >= state.label_temps.length() ||
      state.label_temps[label_id].length() != 1 ||
      !flatten_label_uses_are_routed_scalar_brs(func, label_id) {
      return None
    }
    state.label_temps[label_id][0]
  } else {
    -1
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let mut body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return None
  }
  let mut tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
  if body_count >= 2 && state.terminal_payloads.contains(tail_id) {
    let branch_id = @ir.hot_region_get(func, body_ref, body_count - 2)
    if flatten_terminal_branch_targets_label(func, branch_id, label_id, false) {
      ignore(pass_splice_region(ctx, func, body_ref, body_count - 1, 1, []))
      body_count -= 1
      tail_id = branch_id
    }
  }
  let tail_has_fallthrough_value = @ir.hot_node_result_arity(func, tail_id) == 1
  if !tail_has_fallthrough_value &&
    !flatten_terminal_branch_targets_label(func, tail_id, label_id, false) {
    return None
  }
  let local_id = if routed_local >= 0 {
    routed_local
  } else {
    @ir.hot_append_body_local(func, result_types[0])
  }
  if tail_has_fallthrough_value {
    ignore(
      flatten_set_region_root(
        ctx,
        func,
        body_ref,
        body_count - 1,
        @ir.hot_build_local_set(func, local_id, tail_id),
      ),
    )
  }
  @ir.hot_control_result_type_set(func, block_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_loop_label_param_types(
  func : @ir.HotFunc,
  label_id : Int,
) -> Array[@lib.ValType]? {
  if label_id < 0 || label_id >= func.labels.length() {
    return None
  }
  let owner_id = @ir.hot_label_owner(func, label_id)
  match @ir.hot_node_get(func, owner_id).op {
    @ir.HotOp::Loop => ()
    _ => return None
  }
  match @ir.hot_type_get(func, @ir.hot_node_get(func, owner_id).ty) {
    @ir.HotTypeInfo::BlockResultResolved(_, params, _) => Some(params)
    _ => None
  }
}

///|
fn flatten_loop_backedge_payloads_are_supported(
  func : @ir.HotFunc,
  node_id : Int,
  payload_count : Int,
  param_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Bool {
  if payload_count != param_types.length() {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br | @ir.HotOp::BrTable =>
      if flatten_multivalue_tuple_branch_payload_values(
          func,
          node_id,
          payload_count,
          param_types,
          state~,
        )
        is Some(_) {
        return true
      }
    @ir.HotOp::BrIf => {
      let label_id = @ir.hot_node_get(func, node_id).imm0
      if label_id >= 0 &&
        label_id < func.labels.length() &&
        flatten_multivalue_tuple_loop_br_if_flow(
          func,
          @ir.hot_label_owner(func, label_id),
          node_id,
          param_types,
          use_counts=match state {
            Some(state) => Some(state.use_def)
            None => None
          },
        )
        is Some(_) {
        return true
      }
    }
    _ => ()
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, node_id, slot)
    let payload_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, payload_id).ty,
    )
    if payload_types.length() != 1 ||
      payload_types[0] != param_types[slot] ||
      !flatten_value_type_is_defaultable(param_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, payload_id) {
      return false
    }
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::BrIf if payload_count == 1 => {
      let value_id = @ir.hot_child_get(func, node_id, 0)
      let flow_sites = match state {
        Some(state) if state.rewrites_started =>
          flatten_rewrite_scalar_br_if_flow_sites(
            func, state, node_id, value_id,
          )
        _ => flatten_scalar_br_if_flow_sites(func, node_id, value_id, state~)
      }
      if flow_sites is None {
        return false
      }
    }
    _ => ()
  }
  true
}

///|
fn flatten_loop_backedges_are_supported(
  func : @ir.HotFunc,
  label_id : Int,
  param_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Bool {
  let branch_nodes = match state {
    Some(state) => state.label_branch_nodes[label_id]
    None => flatten_build_label_branch_nodes(func)[label_id]
  }
  for node_id in branch_nodes {
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br if node.imm0 == label_id =>
        if !flatten_loop_backedge_payloads_are_supported(
            func,
            node_id,
            @ir.hot_child_count(func, node_id),
            param_types,
            state~,
          ) {
          return false
        }
      @ir.HotOp::BrIf if node.imm0 == label_id =>
        if !flatten_loop_backedge_payloads_are_supported(
            func,
            node_id,
            @ir.hot_child_count(func, node_id) - 1,
            param_types,
            state~,
          ) {
          return false
        }
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          node.imm0,
          label_id,
        ) =>
        if !flatten_loop_backedge_payloads_are_supported(
            func,
            node_id,
            @ir.hot_child_count(func, node_id) - 1,
            param_types,
            state~,
          ) {
          return false
        }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if node.imm0 == label_id => return false
      _ => ()
    }
  }
  true
}

///|
fn flatten_multivalue_loop_br_if_consumer_matches_payload(
  func : @ir.HotFunc,
  use_counts : @ir.HotNodeUseCounts,
  consumer_id : Int,
  payload_id : Int,
) -> Bool {
  let consumer = @ir.hot_node_get(func, consumer_id)
  match consumer.op {
    @ir.HotOp::Drop if @ir.hot_child_count(func, consumer_id) == 1 => ()
    _ => return false
  }
  let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
  if consumed_id == payload_id {
    return true
  }
  let consumed = @ir.hot_node_get(func, consumed_id)
  if @ir.hot_node_use_count(use_counts, consumed_id) != 1 ||
    @ir.hot_child_count(func, consumed_id) == 0 ||
    @ir.hot_child_get(func, consumed_id, 0) != payload_id {
    return false
  }
  match consumed.op {
    @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 => {
      if !flatten_node_is_simple_operand(
          func,
          @ir.hot_child_get(func, consumed_id, 1),
        ) {
        return false
      }
      let payload_types = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, payload_id).ty,
      )
      let consumed_types = @ir.hot_type_results(func, consumed.ty)
      payload_types.length() == 1 && consumed_types == payload_types
    }
    @ir.HotOp::Unary | @ir.HotOp::Convert =>
      @ir.hot_child_count(func, consumed_id) == 1 &&
      @ir.hot_node_exact_instr(func, consumed_id) is Some(_)
    _ => false
  }
}

///|
fn flatten_multivalue_tuple_br_if_consumer_matches_lane(
  func : @ir.HotFunc,
  use_counts : @ir.HotNodeUseCounts,
  consumer_id : Int,
  tuple_id : Int,
  lane_type : @lib.ValType,
) -> Bool {
  let consumer = @ir.hot_node_get(func, consumer_id)
  match consumer.op {
    @ir.HotOp::Drop if @ir.hot_child_count(func, consumer_id) == 1 => ()
    _ => return false
  }
  let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
  if consumed_id == tuple_id {
    return true
  }
  let consumed = @ir.hot_node_get(func, consumed_id)
  if @ir.hot_node_use_count(use_counts, consumed_id) != 1 ||
    @ir.hot_child_count(func, consumed_id) == 0 ||
    @ir.hot_child_get(func, consumed_id, 0) != tuple_id {
    return false
  }
  match consumed.op {
    @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 =>
      flatten_node_is_simple_operand(
        func,
        @ir.hot_child_get(func, consumed_id, 1),
      ) &&
      @ir.hot_node_exact_instr(func, consumed_id) is Some(_) &&
      @ir.hot_type_results(func, consumed.ty) == [lane_type]
    @ir.HotOp::Unary | @ir.HotOp::Convert =>
      @ir.hot_child_count(func, consumed_id) == 1 &&
      @ir.hot_node_exact_instr(func, consumed_id) is Some(_)
    _ => false
  }
}

///|
fn flatten_replace_multivalue_loop_br_if_consumer_payload(
  func : @ir.HotFunc,
  consumer_id : Int,
  payload_id : Int,
  local_id : Int,
) -> Bool {
  let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
  if consumed_id == payload_id {
    @ir.hot_child_set(
      func,
      consumer_id,
      0,
      @ir.hot_build_local_get(func, local_id),
    )
    return true
  }
  if @ir.hot_child_count(func, consumed_id) == 0 ||
    @ir.hot_child_get(func, consumed_id, 0) != payload_id {
    return false
  }
  @ir.hot_child_set(
    func,
    consumed_id,
    0,
    @ir.hot_build_local_get(func, local_id),
  )
  true
}

///|
fn flatten_multivalue_tuple_loop_br_if_flow(
  func : @ir.HotFunc,
  loop_id : Int,
  branch_id : Int,
  param_types : Array[@lib.ValType],
  use_counts? : @ir.HotNodeUseCounts? = None,
) -> Array[Int]? {
  let payload_count = param_types.length()
  if payload_count <= 1 ||
    @ir.hot_child_count(func, branch_id) != payload_count + 1 {
    return None
  }
  let tuple_id = @ir.hot_child_get(func, branch_id, 0)
  for slot = 1; slot < payload_count; slot = slot + 1 {
    if @ir.hot_child_get(func, branch_id, slot) != tuple_id {
      return None
    }
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return None
  }
  if @ir.hot_type_results(func, tuple.ty) != param_types ||
    @ir.hot_child_count(func, tuple_id) != payload_count {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  let mut branch_root = -1
  for root_idx = 0; root_idx < root_count; root_idx = root_idx + 1 {
    if @ir.hot_region_get(func, body_ref, root_idx) == branch_id {
      if branch_root >= 0 {
        return None
      }
      branch_root = root_idx
    }
  }
  if branch_root < 0 || branch_root + payload_count >= root_count {
    return None
  }
  let counts = match use_counts {
    Some(counts) => counts
    None => flatten_build_node_use_counts(func)
  }
  for offset = 0; offset < payload_count; offset = offset + 1 {
    let consumer_id = @ir.hot_region_get(
      func,
      body_ref,
      branch_root + 1 + offset,
    )
    if !flatten_multivalue_tuple_br_if_consumer_matches_lane(
        func,
        counts,
        consumer_id,
        tuple_id,
        param_types[payload_count - 1 - offset],
      ) {
      return None
    }
  }
  if @ir.hot_node_use_count(counts, tuple_id) != payload_count * 2 {
    return None
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      value_types[0] != param_types[slot] ||
      !flatten_value_type_is_defaultable(param_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return None
    }
  }
  Some([tuple_id, branch_root])
}

///|
fn flatten_multivalue_loop_br_if_flows_are_exact(
  func : @ir.HotFunc,
  loop_id : Int,
  label_id : Int,
  payload_count : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  let branch_nodes = match state {
    Some(state) => state.label_branch_nodes[label_id]
    None => flatten_build_label_branch_nodes(func)[label_id]
  }
  for branch_id in branch_nodes {
    let branch = @ir.hot_node_get(func, branch_id)
    match branch.op {
      @ir.HotOp::BrIf if branch.imm0 == label_id => ()
      _ => continue
    }
    if @ir.hot_child_count(func, branch_id) != payload_count + 1 {
      return false
    }
    let param_types = match flatten_loop_label_param_types(func, label_id) {
      Some(param_types) => param_types
      None => return false
    }
    if flatten_multivalue_tuple_loop_br_if_flow(
        func,
        loop_id,
        branch_id,
        param_types,
        use_counts=Some(use_counts),
      )
      is Some(_) {
      continue
    }
    let mut branch_root = -1
    for root_idx = 0; root_idx < root_count; root_idx = root_idx + 1 {
      if @ir.hot_region_get(func, body_ref, root_idx) == branch_id {
        if branch_root >= 0 {
          return false
        }
        branch_root = root_idx
      }
    }
    if branch_root < 0 || branch_root + payload_count >= root_count {
      return false
    }
    let payloads : Array[Int] = []
    for slot = 0; slot < payload_count; slot = slot + 1 {
      let payload_id = @ir.hot_child_get(func, branch_id, slot)
      if payloads.contains(payload_id) ||
        @ir.hot_node_use_count(use_counts, payload_id) != 2 {
        return false
      }
      payloads.push(payload_id)
    }
    for offset = 0; offset < payload_count; offset = offset + 1 {
      let consumer_id = @ir.hot_region_get(
        func,
        body_ref,
        branch_root + 1 + offset,
      )
      if !flatten_multivalue_loop_br_if_consumer_matches_payload(
          func,
          use_counts,
          consumer_id,
          payloads[payload_count - 1 - offset],
        ) {
        return false
      }
    }
  }
  true
}

///|
fn flatten_rewrite_multivalue_loop_br_if_flows_are_exact(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  loop_id : Int,
  label_id : Int,
  payload_count : Int,
) -> Bool {
  if !state.rewrites_started {
    return false
  }
  flatten_multivalue_loop_br_if_flows_are_exact(
    func,
    loop_id,
    label_id,
    payload_count,
    state=Some(state),
  )
}

///|
fn flatten_inputful_multivalue_loop_tail_is_supported(
  func : @ir.HotFunc,
  loop_id : Int,
  label_id : Int,
  result_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Bool {
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  if flatten_multivalue_region_tail_matches_types(func, body_ref, result_types) ||
    flatten_multivalue_region_tail_tuple_make_has_supported_origins(
      func,
      body_ref,
      result_types,
      state~,
    ) {
    return true
  }
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < result_types.length() {
    return false
  }
  let tail_start = root_count - result_types.length()
  let nested_id = @ir.hot_region_get(func, body_ref, tail_start)
  for slot = 1; slot < result_types.length(); slot = slot + 1 {
    if @ir.hot_region_get(func, body_ref, tail_start + slot) != nested_id {
      return false
    }
  }
  let nested_op = @ir.hot_node_get(func, nested_id).op
  match nested_op {
    @ir.HotOp::Block | @ir.HotOp::If | @ir.HotOp::Try => ()
    _ => return false
  }
  if @ir.hot_type_results(func, @ir.hot_node_get(func, nested_id).ty) !=
    result_types ||
    !flatten_multivalue_control_has_exclusive_region_tail_span(func, nested_id) {
    return false
  }
  let nested_label = @ir.hot_control_node_label(func, nested_id)
  let mut admitted_table = -1
  for table_id = 0; table_id < @ir.hot_node_count(func); table_id = table_id + 1 {
    if !@ir.hot_node_is_live(func, table_id) {
      continue
    }
    let table = @ir.hot_node_get(func, table_id)
    match table.op {
      @ir.HotOp::BrTable => ()
      _ => continue
    }
    if flatten_br_table_targets_label(func, table.imm0, label_id) &&
      flatten_br_table_targets_label(func, table.imm0, nested_label) {
      if admitted_table >= 0 {
        return false
      }
      admitted_table = table_id
    }
  }
  if admitted_table < 0 ||
    @ir.hot_child_count(func, admitted_table) != result_types.length() + 1 {
    return false
  }
  match nested_op {
    @ir.HotOp::Block | @ir.HotOp::If =>
      flatten_multivalue_branch_target_is_supported_with_table(
        func, nested_label, result_types, admitted_table,
      )
    @ir.HotOp::Try =>
      flatten_multivalue_legacy_try_is_supported(func, nested_id)
    _ => false
  }
}

///|
fn flatten_inputful_loop_tuple_entry_values(
  func : @ir.HotFunc,
  loop_id : Int,
  param_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  let input_count = param_types.length()
  if input_count <= 1 || @ir.hot_child_count(func, loop_id) <= input_count {
    return None
  }
  let tuple_id = @ir.hot_child_get(func, loop_id, 0)
  for slot = 1; slot < input_count; slot = slot + 1 {
    if @ir.hot_child_get(func, loop_id, slot) != tuple_id {
      return None
    }
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return None
  }
  if @ir.hot_type_results(func, tuple.ty) != param_types ||
    @ir.hot_child_count(func, tuple_id) != input_count {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  if @ir.hot_region_root_count(func, body_ref) < input_count {
    return None
  }
  for offset = 0; offset < input_count; offset = offset + 1 {
    let consumer_id = @ir.hot_region_get(func, body_ref, offset)
    let consumer = @ir.hot_node_get(func, consumer_id)
    match consumer.op {
      @ir.HotOp::Drop if @ir.hot_child_count(func, consumer_id) == 1 => ()
      _ => return None
    }
    if @ir.hot_child_get(func, consumer_id, 0) != tuple_id {
      return None
    }
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if @ir.hot_node_use_count(use_counts, tuple_id) != input_count * 2 {
    return None
  }
  let values : Array[Int] = []
  for slot = 0; slot < input_count; slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      value_types[0] != param_types[slot] ||
      !flatten_value_type_is_defaultable(param_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return None
    }
    values.push(value_id)
  }
  Some(values)
}

///|
fn flatten_rewrite_inputful_loop_tuple_entry_values(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  loop_id : Int,
  param_types : Array[@lib.ValType],
) -> Array[Int]? {
  if !state.rewrites_started {
    return None
  }
  flatten_inputful_loop_tuple_entry_values(
    func,
    loop_id,
    param_types,
    state=Some(state),
  )
}

///|
fn flatten_inputful_loop_is_supported(
  func : @ir.HotFunc,
  loop_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let loop_node = @ir.hot_node_get(func, loop_id)
  match loop_node.op {
    @ir.HotOp::Loop => ()
    _ => return false
  }
  let label_id = @ir.hot_control_node_label(func, loop_id)
  let input_count = @ir.hot_label_branch_arity(func, label_id)
  if input_count <= 0 {
    return false
  }
  let result_types = @ir.hot_type_results(func, loop_node.ty)
  if result_types.length() == 0 {
    return false
  }
  for result_type in result_types {
    if !flatten_value_type_is_defaultable(result_type) {
      return false
    }
  }
  let param_types = match @ir.hot_type_get(func, loop_node.ty) {
    @ir.HotTypeInfo::BlockResultResolved(_, params, _) => params
    _ => return false
  }
  if param_types.length() != input_count || loop_node.child_count <= input_count {
    return false
  }
  if result_types.length() > 1 {
    let flows_are_exact = match state {
      Some(state) =>
        if state.rewrites_started {
          flatten_rewrite_multivalue_loop_br_if_flows_are_exact(
            func,
            state,
            loop_id,
            label_id,
            param_types.length(),
          )
        } else {
          flatten_multivalue_loop_br_if_flows_are_exact(
            func,
            loop_id,
            label_id,
            param_types.length(),
            state=Some(state),
          )
        }
      None =>
        flatten_multivalue_loop_br_if_flows_are_exact(
          func,
          loop_id,
          label_id,
          param_types.length(),
        )
    }
    if !flows_are_exact {
      return false
    }
  }
  let tuple_entry_values = match state {
    Some(state) if state.rewrites_started =>
      flatten_rewrite_inputful_loop_tuple_entry_values(
        func, state, loop_id, param_types,
      )
    Some(state) =>
      flatten_inputful_loop_tuple_entry_values(
        func,
        loop_id,
        param_types,
        state=Some(state),
      )
    None => flatten_inputful_loop_tuple_entry_values(func, loop_id, param_types)
  }
  if tuple_entry_values is None {
    for slot = 0; slot < input_count; slot = slot + 1 {
      let entry_id = @ir.hot_child_get(func, loop_id, slot)
      let entry_types = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, entry_id).ty,
      )
      if entry_types.length() != 1 ||
        entry_types[0] != param_types[slot] ||
        !flatten_value_type_is_defaultable(param_types[slot]) ||
        !flatten_scalar_branch_payload_has_supported_origin(func, entry_id) {
        return false
      }
    }
  }
  if flatten_cached_label_is_used(func, label_id, state~) &&
    !flatten_loop_backedges_are_supported(func, label_id, param_types, state~) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return false
  }
  if result_types.length() == 1 {
    let tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
    return @ir.hot_node_result_arity(func, tail_id) == 1
  }
  (
    flatten_multivalue_control_has_exclusive_consumer_span(func, loop_id) ||
    flatten_multivalue_control_has_exclusive_region_tail_span(func, loop_id)
  ) &&
  flatten_inputful_multivalue_loop_tail_is_supported(
    func,
    loop_id,
    label_id,
    result_types,
    state~,
  )
}

///|
fn flatten_replace_loop_entry_in_node(
  func : @ir.HotFunc,
  node_id : Int,
  entry_id : Int,
  replacement_id : Int,
  visited : Array[Int],
) -> Unit {
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    visited.contains(node_id) {
    return
  }
  visited.push(node_id)
  let child_count = @ir.hot_child_count(func, node_id)
  for slot = 0; slot < child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id == entry_id {
      @ir.hot_child_set(func, node_id, slot, replacement_id)
    } else {
      flatten_replace_loop_entry_in_node(
        func, child_id, entry_id, replacement_id, visited,
      )
    }
  }
}

///|
fn flatten_prepare_inputful_scalar_loop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  loop_id : Int,
  preludes : Array[Int],
) -> Unit {
  let label_id = @ir.hot_control_node_label(func, loop_id)
  let input_count = @ir.hot_label_branch_arity(func, label_id)
  let param_types = match
    @ir.hot_type_get(func, @ir.hot_node_get(func, loop_id).ty) {
    @ir.HotTypeInfo::BlockResultResolved(_, params, _) => params
    _ => []
  }
  match
    flatten_rewrite_inputful_loop_tuple_entry_values(
      func, state, loop_id, param_types,
    ) {
    Some(values) => {
      let tuple_id = @ir.hot_child_get(func, loop_id, 0)
      let locals : Array[Int] = []
      for slot = 0; slot < values.length(); slot = slot + 1 {
        let local_id = @ir.hot_append_body_local(func, param_types[slot])
        locals.push(local_id)
        state.label_temps[label_id].push(local_id)
        preludes.push(@ir.hot_build_local_set(func, local_id, values[slot]))
      }
      let body_ref = @ir.hot_region_body_ref(func, loop_id)
      for offset = 0; offset < input_count; offset = offset + 1 {
        let consumer_id = @ir.hot_region_get(func, body_ref, offset)
        @ir.hot_child_set(
          func,
          consumer_id,
          0,
          @ir.hot_build_local_get(func, locals[input_count - 1 - offset]),
        )
      }
      ignore(@ir.hot_loop_entry_values_clear(func, loop_id))
      pass_delete_detached_nodes(ctx, func, [tuple_id])
      return
    }
    None => ()
  }
  let entries : Array[Int] = []
  for slot = 0; slot < input_count; slot = slot + 1 {
    entries.push(@ir.hot_child_get(func, loop_id, slot))
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  for entry_id in entries {
    let entry_type = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, entry_id).ty,
      )[0]
    let local_id = @ir.hot_append_body_local(func, entry_type)
    state.label_temps[label_id].push(local_id)
    preludes.push(@ir.hot_build_local_set(func, local_id, entry_id))
    let replacement_id = @ir.hot_build_local_get(func, local_id)
    let visited : Array[Int] = []
    for root_idx = 0
        root_idx < @ir.hot_region_root_count(func, body_ref)
        root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, body_ref, root_idx)
      if root_id == entry_id {
        ignore(@ir.hot_region_set(func, body_ref, root_idx, replacement_id))
      } else {
        flatten_replace_loop_entry_in_node(
          func, root_id, entry_id, replacement_id, visited,
        )
      }
    }
  }
  ignore(@ir.hot_loop_entry_values_clear(func, loop_id))
}

///|
fn flatten_loop_label_uses_are_payloadless(
  func : @ir.HotFunc,
  label_id : Int,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br if node.imm0 == label_id =>
        if @ir.hot_child_count(func, node_id) != 0 {
          return false
        }
      @ir.HotOp::BrIf if node.imm0 == label_id =>
        if @ir.hot_child_count(func, node_id) != 1 {
          return false
        }
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          node.imm0,
          label_id,
        ) => if @ir.hot_child_count(func, node_id) != 1 { return false }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if node.imm0 == label_id => return false
      _ => ()
    }
  }
  true
}

///|
fn flatten_try_route_scalar_loop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  loop_id : Int,
) -> Int? {
  let loop_node = @ir.hot_node_get(func, loop_id)
  match loop_node.op {
    @ir.HotOp::Loop => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, loop_node.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return None
  }
  let label_id = @ir.hot_control_node_label(func, loop_id)
  if @ir.hot_label_branch_arity(func, label_id) != 0 ||
    !flatten_loop_label_uses_are_payloadless(func, label_id) {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return None
  }
  let tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
  if @ir.hot_node_result_arity(func, tail_id) != 1 {
    return None
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  ignore(
    flatten_set_region_root(
      ctx,
      func,
      body_ref,
      body_count - 1,
      @ir.hot_build_local_set(func, local_id, tail_id),
    ),
  )
  @ir.hot_control_result_type_set(func, loop_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_legacy_try_has_deferred_eh_repair(
  func : @ir.HotFunc,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let requirement = match state {
    Some(state) => state.eh_repair_requirement
    None => flatten_eh_repair_requirement(func)
  }
  !requirement.is_clear()
}

///|
fn flatten_scalar_legacy_try_is_supported(
  func : @ir.HotFunc,
  try_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  if try_id < 0 || try_id >= @ir.hot_node_count(func) {
    return false
  }
  match state {
    Some(state) => {
      let entry_index = flatten_scalar_try_entry_index(
        state.scalar_try_entries,
        try_id,
      )
      if entry_index >= 0 {
        return state.scalar_try_entries[entry_index].supported
      }
      if state.rewrites_started {
        return false
      }
    }
    None => ()
  }
  let supported = flatten_scalar_legacy_try_is_supported_uncached(
    func,
    try_id,
    state~,
  )
  match state {
    Some(state) =>
      state.scalar_try_entries.push(
        FlattenScalarTryEntry::new(try_id, supported),
      )
    None => ()
  }
  supported
}

///|
fn flatten_scalar_legacy_try_is_supported_uncached(
  func : @ir.HotFunc,
  try_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let try_node = @ir.hot_node_get(func, try_id)
  match try_node.op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  let result_types = @ir.hot_type_results(func, try_node.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) ||
    flatten_legacy_try_has_deferred_eh_repair(func, state~) {
    return false
  }
  let label_id = @ir.hot_control_node_label(func, try_id)
  let label_is_used = flatten_cached_label_is_used(func, label_id, state~)
  if label_is_used &&
    !flatten_target_can_route_scalar_branches(
      func,
      label_id,
      result_types[0],
      state~,
    ) {
    return false
  }
  let catch_ref = match @ir.hot_region_catch_ref(func, try_id) {
    Some(catch_ref) => catch_ref
    None => return false
  }
  for region_ref in [@ir.hot_region_body_ref(func, try_id), catch_ref] {
    let root_count = @ir.hot_region_root_count(func, region_ref)
    if root_count == 0 {
      return false
    }
    let tail_id = flatten_try_region_effective_terminal_id(
      func,
      region_ref,
      state~,
    )
    let tail_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, tail_id).ty,
    )
    if tail_types.length() == 1 && tail_types[0] == result_types[0] {
      continue
    }
    if label_is_used &&
      flatten_terminal_branch_targets_label(func, tail_id, label_id, true) {
      continue
    }
    return false
  }
  true
}

///|
fn flatten_try_route_scalar_try(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  try_id : Int,
) -> Int? {
  if !flatten_scalar_legacy_try_is_supported(func, try_id, state=Some(state)) {
    return None
  }
  let result_type = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, try_id).ty,
    )[0]
  let label_id = @ir.hot_control_node_label(func, try_id)
  let label_is_used = flatten_cached_label_is_used(
    func,
    label_id,
    state=Some(state),
  )
  let local_id = if label_is_used {
    if label_id < 0 ||
      label_id >= state.label_temps.length() ||
      state.label_temps[label_id].length() != 1 ||
      @ir.hot_local_type(func, state.label_temps[label_id][0]) !=
      Some(result_type) {
      return None
    }
    state.label_temps[label_id][0]
  } else {
    @ir.hot_append_body_local(func, result_type)
  }
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  let regions = [@ir.hot_region_body_ref(func, try_id), catch_ref]
  for region_ref in regions {
    let tail_index = @ir.hot_region_root_count(func, region_ref) - 1
    let tail_id = @ir.hot_region_get(func, region_ref, tail_index)
    if label_is_used &&
      flatten_terminal_branch_targets_label(func, tail_id, label_id, false) {
      continue
    }
    ignore(
      flatten_set_region_root(
        ctx,
        func,
        region_ref,
        tail_index,
        @ir.hot_build_local_set(func, local_id, tail_id),
      ),
    )
  }
  @ir.hot_control_result_type_set(func, try_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_try_route_scalar_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  if_id : Int,
) -> Int? {
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, if_node.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return None
  }
  let label_id = @ir.hot_control_node_label(func, if_id)
  let label_is_used = flatten_cached_label_is_used(
    func,
    label_id,
    state=Some(state),
  )
  let routed_local = if label_is_used {
    if label_id < 0 ||
      label_id >= state.label_temps.length() ||
      state.label_temps[label_id].length() != 1 ||
      !flatten_label_uses_are_routed_scalar_brs(func, label_id) {
      return None
    }
    state.label_temps[label_id][0]
  } else {
    -1
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return None
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  if then_count == 0 || else_count == 0 {
    return None
  }
  let then_tail = @ir.hot_region_get(func, then_ref, then_count - 1)
  let else_tail = @ir.hot_region_get(func, else_ref, else_count - 1)
  let then_has_fallthrough_value = @ir.hot_node_result_arity(func, then_tail) ==
    1
  let else_has_fallthrough_value = @ir.hot_node_result_arity(func, else_tail) ==
    1
  if !then_has_fallthrough_value &&
    !flatten_terminal_branch_targets_label(func, then_tail, label_id, false) {
    return None
  }
  if !else_has_fallthrough_value &&
    !flatten_terminal_branch_targets_label(func, else_tail, label_id, false) {
    return None
  }
  let local_id = if routed_local >= 0 {
    routed_local
  } else {
    @ir.hot_append_body_local(func, result_types[0])
  }
  if then_has_fallthrough_value {
    ignore(
      flatten_set_region_root(
        ctx,
        func,
        then_ref,
        then_count - 1,
        @ir.hot_build_local_set(func, local_id, then_tail),
      ),
    )
  }
  if else_has_fallthrough_value {
    ignore(
      flatten_set_region_root(
        ctx,
        func,
        else_ref,
        else_count - 1,
        @ir.hot_build_local_set(func, local_id, else_tail),
      ),
    )
  }
  @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_try_route_scalar_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
) -> Int? {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block =>
      flatten_try_route_scalar_block(ctx, func, state, node_id)
    @ir.HotOp::Loop => flatten_try_route_scalar_loop(ctx, func, node_id)
    @ir.HotOp::If => flatten_try_route_scalar_if(ctx, func, state, node_id)
    @ir.HotOp::Try => flatten_try_route_scalar_try(ctx, func, state, node_id)
    _ => None
  }
}

///|
fn flatten_scalar_try_br_if_consumer_matches_payload(
  func : @ir.HotFunc,
  use_counts : @ir.HotNodeUseCounts,
  consumer_id : Int,
  value_id : Int,
) -> Bool {
  let consumer = @ir.hot_node_get(func, consumer_id)
  match consumer.op {
    @ir.HotOp::Drop if @ir.hot_child_count(func, consumer_id) == 1 => ()
    _ => return false
  }
  let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
  if consumed_id == value_id {
    return true
  }
  let consumed = @ir.hot_node_get(func, consumed_id)
  if @ir.hot_node_use_count(use_counts, consumed_id) != 1 ||
    @ir.hot_child_count(func, consumed_id) == 0 {
    return false
  }
  match consumed.op {
    @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 => {
      let value_is_left = @ir.hot_child_get(func, consumed_id, 0) == value_id &&
        flatten_node_is_simple_operand(
          func,
          @ir.hot_child_get(func, consumed_id, 1),
        )
      let value_is_right = @ir.hot_child_get(func, consumed_id, 1) == value_id &&
        flatten_node_is_simple_operand(
          func,
          @ir.hot_child_get(func, consumed_id, 0),
        )
      if (!value_is_left && !value_is_right) ||
        @ir.hot_node_exact_instr(func, consumed_id) is None {
        return false
      }
      let value_types = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, value_id).ty,
      )
      value_types.length() == 1 &&
      @ir.hot_type_results(func, consumed.ty) == value_types
    }
    @ir.HotOp::Unary | @ir.HotOp::Convert =>
      @ir.hot_child_count(func, consumed_id) == 1 &&
      @ir.hot_child_get(func, consumed_id, 0) == value_id &&
      @ir.hot_node_exact_instr(func, consumed_id) is Some(_)
    _ => false
  }
}

///|
fn flatten_scalar_try_br_if_flow_is_exact(
  func : @ir.HotFunc,
  try_id : Int,
  branch_id : Int,
  value_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let branch = @ir.hot_node_get(func, branch_id)
  match branch.op {
    @ir.HotOp::BrIf if branch.imm0 == @ir.hot_control_node_label(func, try_id) &&
      @ir.hot_child_count(func, branch_id) == 2 &&
      @ir.hot_child_get(func, branch_id, 0) == value_id => ()
    _ => return false
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if @ir.hot_node_use_count(use_counts, value_id) != 2 {
    return false
  }
  let catch_ref = match @ir.hot_region_catch_ref(func, try_id) {
    Some(catch_ref) => catch_ref
    None => return false
  }
  for region_ref in [@ir.hot_region_body_ref(func, try_id), catch_ref] {
    let root_count = @ir.hot_region_root_count(func, region_ref)
    for root_idx = 0; root_idx + 1 < root_count; root_idx = root_idx + 1 {
      if @ir.hot_region_get(func, region_ref, root_idx) != branch_id {
        continue
      }
      let consumer_id = @ir.hot_region_get(func, region_ref, root_idx + 1)
      return flatten_scalar_try_br_if_consumer_matches_payload(
        func, use_counts, consumer_id, value_id,
      )
    }
  }
  false
}

///|
fn flatten_rewrite_scalar_try_br_if_flow_is_exact(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  try_id : Int,
  branch_id : Int,
  value_id : Int,
) -> Bool {
  if !state.rewrites_started {
    return false
  }
  flatten_scalar_try_br_if_flow_is_exact(
    func,
    try_id,
    branch_id,
    value_id,
    state=Some(state),
  )
}

///|
fn flatten_scalar_br_if_current_flow_sites(
  func : @ir.HotFunc,
  branch_id : Int,
  value_id : Int,
  cached_sites : Array[Int],
) -> Array[Int]? {
  if cached_sites.length() % 2 != 0 ||
    @ir.hot_child_count(func, branch_id) < 1 ||
    @ir.hot_child_get(func, branch_id, 0) != value_id {
    return None
  }
  let parents : Array[Int] = []
  let expected_counts : Array[Int] = []
  for site = 0; site < cached_sites.length(); site = site + 2 {
    let parent_id = cached_sites[site]
    let mut parent_idx = -1
    for i = 0; i < parents.length(); i = i + 1 {
      if parents[i] == parent_id {
        parent_idx = i
      }
    }
    if parent_idx < 0 {
      parents.push(parent_id)
      expected_counts.push(1)
    } else {
      expected_counts[parent_idx] = expected_counts[parent_idx] + 1
    }
  }
  let current_sites : Array[Int] = []
  for parent_idx = 0; parent_idx < parents.length(); parent_idx = parent_idx + 1 {
    let parent_id = parents[parent_idx]
    let mut found = 0
    if parent_id < 0 {
      for root_idx = 0
          root_idx < @ir.hot_root_count(func)
          root_idx = root_idx + 1 {
        if @ir.hot_root_get(func, root_idx) == value_id {
          current_sites.push(-1)
          current_sites.push(root_idx)
          found = found + 1
        }
      }
    } else {
      if !@ir.hot_node_is_live(func, parent_id) {
        return None
      }
      for slot = 0; slot < @ir.hot_child_count(func, parent_id); slot = slot + 1 {
        if @ir.hot_child_get(func, parent_id, slot) == value_id &&
          !(parent_id == branch_id && slot == 0) {
          current_sites.push(parent_id)
          current_sites.push(slot)
          found = found + 1
        }
      }
    }
    if found != expected_counts[parent_idx] {
      return None
    }
  }
  Some(current_sites)
}

///|
fn flatten_locate_scalar_br_if_flow_sites(
  func : @ir.HotFunc,
  branch_id : Int,
  value_id : Int,
) -> Array[Int]? {
  if branch_id < 0 ||
    branch_id >= @ir.hot_node_count(func) ||
    !@ir.hot_node_is_live(func, branch_id) ||
    @ir.hot_child_count(func, branch_id) < 1 ||
    @ir.hot_child_get(func, branch_id, 0) != value_id {
    return None
  }
  let sites : Array[Int] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      if @ir.hot_child_get(func, node_id, slot) == value_id &&
        !(node_id == branch_id && slot == 0) {
        sites.push(node_id)
        sites.push(slot)
      }
    }
  }
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    if @ir.hot_root_get(func, root_idx) == value_id {
      sites.push(-1)
      sites.push(root_idx)
    }
  }
  Some(sites)
}

///|
fn flatten_scalar_br_if_flow_sites(
  func : @ir.HotFunc,
  branch_id : Int,
  value_id : Int,
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  let cached_sites = match state {
    Some(state) => {
      let entry_index = flatten_scalar_br_if_flow_entry_index(
        state.scalar_br_if_flow_entries,
        branch_id,
      )
      if entry_index >= 0 {
        let entry = state.scalar_br_if_flow_entries[entry_index]
        if entry.value_id != value_id {
          return None
        }
        Some(entry.sites)
      } else {
        if state.rewrites_started {
          return None
        }
        let sites = flatten_locate_scalar_br_if_flow_sites(
          func, branch_id, value_id,
        )
        match sites {
          Some(sites) =>
            state.scalar_br_if_flow_entries.push(
              FlattenScalarBrIfFlowEntry::new(branch_id, value_id, sites),
            )
          None => ()
        }
        sites
      }
    }
    None => flatten_locate_scalar_br_if_flow_sites(func, branch_id, value_id)
  }
  let sites = match cached_sites {
    Some(sites) => sites
    None => return None
  }
  flatten_scalar_br_if_current_flow_sites(func, branch_id, value_id, sites)
}

///|
fn flatten_rewrite_scalar_br_if_flow_sites(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  branch_id : Int,
  value_id : Int,
) -> Array[Int]? {
  if !state.rewrites_started {
    return None
  }
  let entry_index = flatten_scalar_br_if_flow_entry_index(
    state.scalar_br_if_flow_entries,
    branch_id,
  )
  if entry_index < 0 {
    return None
  }
  let cached_value = state.scalar_br_if_flow_entries[entry_index].value_id
  if @ir.hot_child_count(func, branch_id) < 1 {
    return None
  }
  let current_value = @ir.hot_child_get(func, branch_id, 0)
  if current_value != cached_value {
    if flatten_scalar_flow_replacement(
        state.scalar_flow_replacement_entries,
        cached_value,
      ) !=
      current_value {
      return None
    }
    return Some([])
  }
  if value_id != cached_value {
    return None
  }
  flatten_scalar_br_if_flow_sites(func, branch_id, value_id, state=Some(state))
}

///|
fn flatten_target_can_route_scalar_branches(
  func : @ir.HotFunc,
  label_id : Int,
  target_type : @lib.ValType,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let owner_id = @ir.hot_label_owner(func, label_id)
  let owner = @ir.hot_node_get(func, owner_id)
  let target_regions : Array[@ir.HotRegionRef] = match owner.op {
    @ir.HotOp::Block => [@ir.hot_region_body_ref(func, owner_id)]
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, owner_id) {
        Some(else_ref) => [@ir.hot_region_then_ref(func, owner_id), else_ref]
        None => return false
      }
    @ir.HotOp::Try =>
      match @ir.hot_region_catch_ref(func, owner_id) {
        Some(catch_ref) => [@ir.hot_region_body_ref(func, owner_id), catch_ref]
        None => return false
      }
    _ => return false
  }
  for target_region in target_regions {
    let root_count = @ir.hot_region_root_count(func, target_region)
    if root_count == 0 {
      return false
    }
    let tail_id = match owner.op {
      @ir.HotOp::Try =>
        flatten_try_region_effective_terminal_id(func, target_region, state~)
      _ => @ir.hot_region_get(func, target_region, root_count - 1)
    }
    if @ir.hot_node_result_arity(func, tail_id) != 1 &&
      !flatten_terminal_branch_targets_label(func, tail_id, label_id, true) {
      return false
    }
  }
  let mut saw_target = false
  let branch_nodes = match state {
    Some(state) => state.label_branch_nodes[label_id]
    None => flatten_build_label_branch_nodes(func)[label_id]
  }
  for branch_id in branch_nodes {
    let branch = @ir.hot_node_get(func, branch_id)
    match branch.op {
      @ir.HotOp::Br if branch.imm0 == label_id => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, branch_id)
        if child_count == 0 {
          continue
        }
        if child_count != 1 {
          return false
        }
        let value_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, @ir.hot_child_get(func, branch_id, 0)).ty,
        )
        if value_types.length() != 1 || value_types[0] != target_type {
          return false
        }
      }
      @ir.HotOp::BrIf if branch.imm0 == label_id => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, branch_id)
        if child_count == 1 {
          continue
        }
        if child_count != 2 {
          return false
        }
        let value_id = @ir.hot_child_get(func, branch_id, 0)
        let value_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, value_id).ty,
        )
        if value_types.length() != 1 ||
          !flatten_value_type_is_defaultable(value_types[0]) {
          return false
        }
        match owner.op {
          @ir.HotOp::Try => {
            let flow_is_exact = match state {
              Some(state) if state.rewrites_started =>
                flatten_rewrite_scalar_try_br_if_flow_is_exact(
                  func, state, owner_id, branch_id, value_id,
                )
              _ =>
                flatten_scalar_try_br_if_flow_is_exact(
                  func,
                  owner_id,
                  branch_id,
                  value_id,
                  state~,
                )
            }
            if value_types[0] != target_type ||
              !flatten_scalar_branch_payload_has_supported_origin(
                func, value_id,
              ) ||
              !flow_is_exact {
              return false
            }
          }
          _ => ()
        }
        let flow_sites = match state {
          Some(state) if state.rewrites_started =>
            flatten_rewrite_scalar_br_if_flow_sites(
              func, state, branch_id, value_id,
            )
          _ =>
            flatten_scalar_br_if_flow_sites(func, branch_id, value_id, state~)
        }
        if flow_sites is None {
          return false
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if branch.imm0 == label_id => return false
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          branch.imm0,
          label_id,
        ) => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, branch_id)
        if child_count == 1 {
          continue
        }
        if child_count != 2 {
          return false
        }
        let value_id = @ir.hot_child_get(func, branch_id, 0)
        let value_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, value_id).ty,
        )
        if value_types.length() != 1 ||
          value_types[0] != target_type ||
          !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
          return false
        }
        match owner.op {
          @ir.HotOp::Try =>
            if !flatten_try_terminal_br_table_targets_label(
                func,
                branch_id,
                label_id,
                1,
                true,
                state~,
              ) {
              return false
            }
          _ => ()
        }
      }
      _ => ()
    }
  }
  saw_target
}

///|
fn flatten_rewrite_target_can_route_scalar_branches(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  label_id : Int,
  target_type : @lib.ValType,
) -> Bool {
  flatten_target_can_route_scalar_branches(
    func,
    label_id,
    target_type,
    state=Some(state),
  )
}

///|
fn flatten_multivalue_br_if_cached_flow_is_current(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
  flow : Array[Int],
) -> Bool {
  if flow.length() != 2 ||
    payload_count <= 1 ||
    @ir.hot_child_count(func, branch_id) != payload_count + 1 ||
    flow[0] < 0 ||
    !@ir.hot_node_is_live(func, flow[0]) ||
    flow[1] < 0 ||
    flow[1] + payload_count > @ir.hot_child_count(func, flow[0]) {
    return false
  }
  let payloads : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, branch_id, slot)
    if payloads.contains(payload_id) ||
      @ir.hot_child_get(func, flow[0], flow[1] + slot) != payload_id {
      return false
    }
    payloads.push(payload_id)
  }
  true
}

///|
fn flatten_locate_reachable_multivalue_br_if_flow_span(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
) -> Array[Int]? {
  let payloads : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, branch_id, slot)
    if payloads.contains(payload_id) {
      return None
    }
    payloads.push(payload_id)
  }
  let seen = @bitset.BitSet::new(@ir.hot_node_count(func))
  let worklist : Array[Int] = []
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root_id = @ir.hot_root_get(func, root_idx)
    if payloads.contains(root_id) {
      return None
    }
    if @ir.hot_node_is_live(func, root_id) && !seen[root_id] {
      seen[root_id] = true
      worklist.push(root_id)
    }
  }
  let parents = Array::make(payload_count, -1)
  let slots = Array::make(payload_count, -1)
  let counts = Array::make(payload_count, 0)
  while !worklist.is_empty() {
    let node_id = worklist.pop().unwrap()
    let child_count = @ir.hot_child_count(func, node_id)
    for child_slot = 0; child_slot < child_count; child_slot = child_slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, child_slot)
      for payload_slot = 0
          payload_slot < payload_count
          payload_slot = payload_slot + 1 {
        if child_id != payloads[payload_slot] {
          continue
        }
        counts[payload_slot] = counts[payload_slot] + 1
        if node_id == branch_id && child_slot == payload_slot {
          continue
        }
        if parents[payload_slot] >= 0 {
          return None
        }
        parents[payload_slot] = node_id
        slots[payload_slot] = child_slot
      }
      if @ir.hot_node_is_live(func, child_id) && !seen[child_id] {
        seen[child_id] = true
        worklist.push(child_id)
      }
    }
  }
  let parent_id = parents[0]
  let start_slot = slots[0]
  if parent_id < 0 || start_slot < 0 {
    return None
  }
  for payload_slot = 0
      payload_slot < payload_count
      payload_slot = payload_slot + 1 {
    if counts[payload_slot] != 2 ||
      parents[payload_slot] != parent_id ||
      slots[payload_slot] != start_slot + payload_slot {
      return None
    }
  }
  Some([parent_id, start_slot])
}

///|
fn flatten_multivalue_br_if_flow_span(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  if payload_count <= 1 ||
    @ir.hot_child_count(func, branch_id) != payload_count + 1 {
    return None
  }
  let cached_flow = match state {
    Some(state) => {
      let entry_index = flatten_br_if_flow_entry_index(
        state.multivalue_br_if_flow_entries,
        branch_id,
      )
      if entry_index >= 0 {
        state.multivalue_br_if_flow_entries[entry_index].flow
      } else {
        if state.rewrites_started {
          return None
        }
        let flow = flatten_locate_reachable_multivalue_br_if_flow_span(
          func, branch_id, payload_count,
        )
        state.multivalue_br_if_flow_entries.push(
          FlattenBrIfFlowEntry::new(branch_id, flow),
        )
        flow
      }
    }
    None =>
      flatten_locate_reachable_multivalue_br_if_flow_span(
        func, branch_id, payload_count,
      )
  }
  let flow = match cached_flow {
    Some(flow) => flow
    None => return None
  }
  if !flatten_multivalue_br_if_cached_flow_is_current(
      func, branch_id, payload_count, flow,
    ) {
    return None
  }
  Some(flow)
}

///|
fn flatten_rewrite_multivalue_br_if_flow_span(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  branch_id : Int,
  payload_count : Int,
) -> Array[Int]? {
  if !state.rewrites_started ||
    flatten_br_if_flow_entry_index(
      state.multivalue_br_if_flow_entries,
      branch_id,
    ) <
    0 {
    return None
  }
  flatten_multivalue_br_if_flow_span(
    func,
    branch_id,
    payload_count,
    state=Some(state),
  )
}

///|
fn flatten_tuple_br_if_cached_flow_is_current(
  func : @ir.HotFunc,
  tuple_id : Int,
  payload_count : Int,
  flow : Array[Int],
) -> Bool {
  if flow.length() != 3 ||
    flow[0] != tuple_id ||
    flow[1] < 0 ||
    !@ir.hot_node_is_live(func, flow[1]) ||
    flow[2] < 0 ||
    flow[2] + payload_count > @ir.hot_child_count(func, flow[1]) {
    return false
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    if @ir.hot_child_get(func, flow[1], flow[2] + slot) != tuple_id {
      return false
    }
  }
  true
}

///|
fn flatten_locate_reachable_tuple_br_if_flow(
  func : @ir.HotFunc,
  branch_id : Int,
  tuple_id : Int,
  payload_count : Int,
) -> Array[Int]? {
  let seen = @bitset.BitSet::new(@ir.hot_node_count(func))
  let worklist : Array[Int] = []
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root_id = @ir.hot_root_get(func, root_idx)
    if root_id == tuple_id {
      return None
    }
    if @ir.hot_node_is_live(func, root_id) && !seen[root_id] {
      seen[root_id] = true
      worklist.push(root_id)
    }
  }
  let branch_slots = Array::make(payload_count, false)
  let flow_slots : Array[Int] = []
  let mut flow_parent = -1
  let mut site_count = 0
  while !worklist.is_empty() {
    let node_id = worklist.pop().unwrap()
    let child_count = @ir.hot_child_count(func, node_id)
    for child_slot = 0; child_slot < child_count; child_slot = child_slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, child_slot)
      if child_id == tuple_id {
        site_count = site_count + 1
        if node_id == branch_id && child_slot < payload_count {
          if branch_slots[child_slot] {
            return None
          }
          branch_slots[child_slot] = true
        } else {
          if flow_parent < 0 {
            flow_parent = node_id
          } else if flow_parent != node_id {
            return None
          }
          if flow_slots.contains(child_slot) {
            return None
          }
          flow_slots.push(child_slot)
        }
      }
      if @ir.hot_node_is_live(func, child_id) && !seen[child_id] {
        seen[child_id] = true
        worklist.push(child_id)
      }
    }
  }
  if site_count != payload_count * 2 ||
    flow_parent < 0 ||
    flow_slots.length() != payload_count {
    return None
  }
  flow_slots.sort()
  let flow_start = flow_slots[0]
  for slot = 0; slot < payload_count; slot = slot + 1 {
    if !branch_slots[slot] || flow_slots[slot] != flow_start + slot {
      return None
    }
  }
  Some([tuple_id, flow_parent, flow_start])
}

///|
fn flatten_multivalue_tuple_br_if_flow(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
  target_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  if payload_count <= 1 ||
    target_types.length() != payload_count ||
    @ir.hot_child_count(func, branch_id) != payload_count + 1 {
    return None
  }
  let tuple_id = @ir.hot_child_get(func, branch_id, 0)
  for slot = 1; slot < payload_count; slot = slot + 1 {
    if @ir.hot_child_get(func, branch_id, slot) != tuple_id {
      return None
    }
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return None
  }
  if @ir.hot_type_results(func, tuple.ty) != target_types ||
    @ir.hot_child_count(func, tuple_id) != payload_count {
    return None
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if @ir.hot_node_use_count(use_counts, tuple_id) != payload_count * 2 {
    return None
  }
  let cached_flow = match state {
    Some(state) => {
      let entry_index = flatten_br_if_flow_entry_index(
        state.tuple_br_if_flow_entries,
        branch_id,
      )
      if entry_index >= 0 {
        state.tuple_br_if_flow_entries[entry_index].flow
      } else {
        if state.rewrites_started {
          return None
        }
        let flow = flatten_locate_reachable_tuple_br_if_flow(
          func, branch_id, tuple_id, payload_count,
        )
        state.tuple_br_if_flow_entries.push(
          FlattenBrIfFlowEntry::new(branch_id, flow),
        )
        flow
      }
    }
    None =>
      flatten_locate_reachable_tuple_br_if_flow(
        func, branch_id, tuple_id, payload_count,
      )
  }
  let flow = match cached_flow {
    Some(flow) => flow
    None => return None
  }
  if !flatten_tuple_br_if_cached_flow_is_current(
      func, tuple_id, payload_count, flow,
    ) {
    return None
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      value_types[0] != target_types[slot] ||
      !flatten_value_type_is_defaultable(target_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return None
    }
  }
  Some(flow)
}

///|
fn flatten_rewrite_multivalue_tuple_br_if_flow(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  branch_id : Int,
  payload_count : Int,
  target_types : Array[@lib.ValType],
) -> Array[Int]? {
  if !state.rewrites_started ||
    flatten_br_if_flow_entry_index(state.tuple_br_if_flow_entries, branch_id) <
    0 {
    return None
  }
  flatten_multivalue_tuple_br_if_flow(
    func,
    branch_id,
    payload_count,
    target_types,
    state=Some(state),
  )
}

///|
fn flatten_multivalue_tuple_branch_payload_values(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
  target_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  if payload_count <= 1 || target_types.length() != payload_count {
    return None
  }
  let tuple_id = @ir.hot_child_get(func, branch_id, 0)
  for slot = 1; slot < payload_count; slot = slot + 1 {
    if @ir.hot_child_get(func, branch_id, slot) != tuple_id {
      return None
    }
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return None
  }
  if @ir.hot_type_results(func, tuple.ty) != target_types ||
    @ir.hot_child_count(func, tuple_id) != payload_count {
    return None
  }
  let use_counts = match state {
    Some(state) => state.use_def
    None => flatten_build_node_use_counts(func)
  }
  if @ir.hot_node_use_count(use_counts, tuple_id) != payload_count {
    return None
  }
  let values : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      value_types[0] != target_types[slot] ||
      !flatten_value_type_is_defaultable(target_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return None
    }
    values.push(value_id)
  }
  Some(values)
}

///|
fn flatten_rewrite_multivalue_tuple_branch_payload_values(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  branch_id : Int,
  payload_count : Int,
  target_types : Array[@lib.ValType],
) -> Array[Int]? {
  if !state.rewrites_started {
    return None
  }
  flatten_multivalue_tuple_branch_payload_values(
    func,
    branch_id,
    payload_count,
    target_types,
    state=Some(state),
  )
}

///|
fn flatten_br_table_payload_types(
  func : @ir.HotFunc,
  table_id : Int,
  payload_count : Int,
  state? : FlattenRewriteState? = None,
) -> Array[@lib.ValType]? {
  if payload_count <= 0 {
    return None
  }
  let targets = flatten_unique_br_table_targets(
    func,
    @ir.hot_node_get(func, table_id).imm0,
  )
  if targets.length() == 0 {
    return None
  }
  let first_target = targets[0]
  if first_target < 0 || first_target >= func.labels.length() {
    return None
  }
  let expected_types = match @ir.hot_label_kind(func, first_target) {
    @ir.HotLabelKind::LoopLabel =>
      match flatten_loop_label_param_types(func, first_target) {
        Some(param_types) => param_types
        None => return None
      }
    @ir.HotLabelKind::BlockLabel
    | @ir.HotLabelKind::IfLabel
    | @ir.HotLabelKind::TryLabel =>
      @ir.hot_type_results(func, @ir.hot_label_result_type(func, first_target))
    _ => return None
  }
  if expected_types.length() == payload_count &&
    flatten_multivalue_tuple_branch_payload_values(
      func,
      table_id,
      payload_count,
      expected_types,
      state~,
    )
    is Some(_) {
    return Some(expected_types)
  }
  let payload_types : Array[@lib.ValType] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, table_id, slot)
    let value_types = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
    )
    if value_types.length() != 1 ||
      !flatten_value_type_is_defaultable(value_types[0]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return None
    }
    payload_types.push(value_types[0])
  }
  Some(payload_types)
}

///|
fn flatten_multivalue_branch_target_is_supported_with_table(
  func : @ir.HotFunc,
  label_id : Int,
  target_types : Array[@lib.ValType],
  admitted_table_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  if target_types.length() <= 1 ||
    @ir.hot_label_branch_arity(func, label_id) != target_types.length() {
    return false
  }
  let owner_id = @ir.hot_label_owner(func, label_id)
  if !flatten_multivalue_control_has_exclusive_consumer_span(func, owner_id) &&
    !(admitted_table_id >= 0 &&
    flatten_multivalue_control_has_exclusive_region_tail_span(func, owner_id)) {
    return false
  }
  let regions : Array[@ir.HotRegionRef] = match
    @ir.hot_node_get(func, owner_id).op {
    @ir.HotOp::Block => [@ir.hot_region_body_ref(func, owner_id)]
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, owner_id) {
        Some(else_ref) => [@ir.hot_region_then_ref(func, owner_id), else_ref]
        None => return false
      }
    _ => return false
  }
  for region_ref in regions {
    let root_count = @ir.hot_region_root_count(func, region_ref)
    if root_count == 0 {
      return false
    }
    let tail_id = @ir.hot_region_get(func, region_ref, root_count - 1)
    let tail = @ir.hot_node_get(func, tail_id)
    let has_terminal_target_branch = match tail.op {
      @ir.HotOp::Br =>
        tail.imm0 == label_id &&
        @ir.hot_child_count(func, tail_id) == target_types.length()
      @ir.HotOp::BrTable =>
        tail_id == admitted_table_id &&
        flatten_br_table_targets_label(func, tail.imm0, label_id) &&
        @ir.hot_child_count(func, tail_id) == target_types.length() + 1
      _ => false
    }
    let has_nested_table_target_tail = if admitted_table_id >= 0 &&
      root_count >= target_types.length() {
      let tail_start = root_count - target_types.length()
      let nested_id = @ir.hot_region_get(func, region_ref, tail_start)
      let mut repeated = nested_id != owner_id
      for slot = 1; slot < target_types.length(); slot = slot + 1 {
        if @ir.hot_region_get(func, region_ref, tail_start + slot) != nested_id {
          repeated = false
        }
      }
      let nested_types = @ir.hot_type_results(
        func,
        @ir.hot_node_get(func, nested_id).ty,
      )
      if repeated && nested_types == target_types {
        match @ir.hot_node_get(func, nested_id).op {
          @ir.HotOp::Block | @ir.HotOp::If => {
            let nested_label = @ir.hot_control_node_label(func, nested_id)
            flatten_br_table_targets_label(
              func,
              @ir.hot_node_get(func, admitted_table_id).imm0,
              nested_label,
            ) &&
            flatten_multivalue_branch_target_is_supported_with_table(
              func,
              nested_label,
              target_types,
              admitted_table_id,
              state~,
            )
          }
          @ir.HotOp::Loop => {
            let nested_label = @ir.hot_control_node_label(func, nested_id)
            flatten_br_table_targets_label(
              func,
              @ir.hot_node_get(func, admitted_table_id).imm0,
              nested_label,
            ) &&
            (
              flatten_inputful_loop_is_supported(func, nested_id, state~) ||
              @ir.hot_label_branch_arity(func, nested_label) == 0
            )
          }
          @ir.HotOp::Try => {
            let nested_label = @ir.hot_control_node_label(func, nested_id)
            flatten_br_table_targets_label(
              func,
              @ir.hot_node_get(func, admitted_table_id).imm0,
              nested_label,
            ) &&
            flatten_multivalue_legacy_try_is_supported(func, nested_id, state~)
          }
          _ => false
        }
      } else {
        false
      }
    } else {
      false
    }
    if !has_terminal_target_branch &&
      !has_nested_table_target_tail &&
      !flatten_multivalue_region_tail_matches_types(
        func, region_ref, target_types,
      ) &&
      !flatten_multivalue_region_tail_repeats_tuple(
        func, region_ref, target_types,
      ) {
      return false
    }
  }
  let mut saw_target = false
  let branch_nodes = match state {
    Some(state) => state.label_branch_nodes[label_id]
    None => flatten_build_label_branch_nodes(func)[label_id]
  }
  for branch_id in branch_nodes {
    let branch = @ir.hot_node_get(func, branch_id)
    match branch.op {
      @ir.HotOp::Br if branch.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, branch_id) != target_types.length() {
          return false
        }
        if flatten_multivalue_tuple_branch_payload_values(
            func,
            branch_id,
            target_types.length(),
            target_types,
            state~,
          )
          is None {
          for slot = 0; slot < target_types.length(); slot = slot + 1 {
            let payload_id = @ir.hot_child_get(func, branch_id, slot)
            let payload_types = @ir.hot_type_results(
              func,
              @ir.hot_node_get(func, payload_id).ty,
            )
            if payload_types.length() != 1 ||
              payload_types[0] != target_types[slot] ||
              !flatten_value_type_is_defaultable(target_types[slot]) ||
              !flatten_scalar_branch_payload_has_supported_origin(
                func, payload_id,
              ) {
              return false
            }
          }
        }
      }
      @ir.HotOp::BrIf if branch.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, branch_id) != target_types.length() + 1 {
          return false
        }
        let tuple_flow = flatten_multivalue_tuple_br_if_flow(
          func,
          branch_id,
          target_types.length(),
          target_types,
          state~,
        )
        if tuple_flow is None {
          for slot = 0; slot < target_types.length(); slot = slot + 1 {
            let payload_id = @ir.hot_child_get(func, branch_id, slot)
            let payload_types = @ir.hot_type_results(
              func,
              @ir.hot_node_get(func, payload_id).ty,
            )
            if payload_types.length() != 1 ||
              payload_types[0] != target_types[slot] ||
              !flatten_value_type_is_defaultable(target_types[slot]) ||
              !flatten_scalar_branch_payload_has_supported_origin(
                func, payload_id,
              ) {
              return false
            }
          }
        }
        let flow_span = match tuple_flow {
          Some(flow) => [flow[1], flow[2]]
          None =>
            match
              flatten_multivalue_br_if_flow_span(
                func,
                branch_id,
                target_types.length(),
                state~,
              ) {
              Some(flow_span) => flow_span
              None => return false
            }
        }
        let mut matches_region_tail = false
        for region_ref in regions {
          let root_count = @ir.hot_region_root_count(func, region_ref)
          if flow_span[0] == region_ref.holder &&
            flow_span[1] == root_count - target_types.length() {
            matches_region_tail = true
          }
        }
        if !matches_region_tail {
          return false
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if branch.imm0 == label_id => return false
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          branch.imm0,
          label_id,
        ) => {
        saw_target = true
        if branch_id != admitted_table_id ||
          @ir.hot_child_count(func, branch_id) != target_types.length() + 1 {
          return false
        }
        if flatten_multivalue_tuple_branch_payload_values(
            func,
            branch_id,
            target_types.length(),
            target_types,
            state~,
          )
          is None {
          for slot = 0; slot < target_types.length(); slot = slot + 1 {
            let payload_id = @ir.hot_child_get(func, branch_id, slot)
            let payload_types = @ir.hot_type_results(
              func,
              @ir.hot_node_get(func, payload_id).ty,
            )
            if payload_types.length() != 1 ||
              payload_types[0] != target_types[slot] ||
              !flatten_value_type_is_defaultable(target_types[slot]) ||
              !flatten_scalar_branch_payload_has_supported_origin(
                func, payload_id,
              ) {
              return false
            }
          }
        }
      }
      _ => ()
    }
  }
  saw_target
}

///|
fn flatten_multivalue_branch_target_is_supported(
  func : @ir.HotFunc,
  label_id : Int,
  target_types : Array[@lib.ValType],
  state? : FlattenRewriteState? = None,
) -> Bool {
  flatten_multivalue_branch_target_is_supported_with_table(
    func,
    label_id,
    target_types,
    -1,
    state~,
  )
}

///|
fn flatten_rewrite_multivalue_branch_target_is_supported(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  label_id : Int,
  target_types : Array[@lib.ValType],
  admitted_table_id : Int,
) -> Bool {
  flatten_multivalue_branch_target_is_supported_with_table(
    func,
    label_id,
    target_types,
    admitted_table_id,
    state=Some(state),
  )
}

///|
fn flatten_try_route_br(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  match branch.op {
    @ir.HotOp::Br if @ir.hot_child_count(func, node_id) > 0 => ()
    _ => return false
  }
  let label_id = branch.imm0
  if label_id < 0 || label_id >= state.label_temps.length() {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let value_types = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
  )
  match @ir.hot_label_kind(func, label_id) {
    @ir.HotLabelKind::LoopLabel => {
      let locals = state.label_temps[label_id]
      let child_count = @ir.hot_child_count(func, node_id)
      if child_count != locals.length() {
        return false
      }
      let param_types : Array[@lib.ValType] = []
      for local_id in locals {
        match @ir.hot_local_type(func, local_id) {
          Some(value_type) => param_types.push(value_type)
          None => return false
        }
      }
      let tuple_values = flatten_rewrite_multivalue_tuple_branch_payload_values(
        func, state, node_id, child_count, param_types,
      )
      if tuple_values is None {
        for slot = 0; slot < child_count; slot = slot + 1 {
          let payload_id = @ir.hot_child_get(func, node_id, slot)
          let payload_types = @ir.hot_type_results(
            func,
            @ir.hot_node_get(func, payload_id).ty,
          )
          if payload_types.length() != 1 ||
            @ir.hot_local_type(func, locals[slot]) != Some(payload_types[0]) {
            return false
          }
        }
      }
      for slot = 0; slot < child_count; slot = slot + 1 {
        let payload_id = match tuple_values {
          Some(values) => values[slot]
          None => @ir.hot_child_get(func, node_id, slot)
        }
        preludes.push(@ir.hot_build_local_set(func, locals[slot], payload_id))
      }
      let tuple_id = if tuple_values is Some(_) {
        @ir.hot_child_get(func, node_id, 0)
      } else {
        -1
      }
      ignore(@ir.hot_replace_child_span(func, node_id, []))
      if tuple_id >= 0 {
        pass_delete_detached_nodes(ctx, func, [tuple_id])
      }
      return true
    }
    @ir.HotLabelKind::BlockLabel
    | @ir.HotLabelKind::IfLabel
    | @ir.HotLabelKind::TryLabel => ()
    _ => return false
  }
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
  )
  let child_count = @ir.hot_child_count(func, node_id)
  if child_count > 1 {
    let target_is_supported = match @ir.hot_label_kind(func, label_id) {
      @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel =>
        flatten_rewrite_multivalue_branch_target_is_supported(
          func, state, label_id, target_types, -1,
        )
      @ir.HotLabelKind::TryLabel =>
        flatten_multivalue_legacy_try_is_supported(
          func,
          @ir.hot_label_owner(func, label_id),
        )
      _ => false
    }
    if target_types.length() != child_count || !target_is_supported {
      return false
    }
    let locals = match
      flatten_ensure_label_temps(func, state, label_id, target_types) {
      Some(locals) => locals
      None => return false
    }
    let tuple_values = flatten_rewrite_multivalue_tuple_branch_payload_values(
      func, state, node_id, child_count, target_types,
    )
    for slot = 0; slot < child_count; slot = slot + 1 {
      let payload_id = match tuple_values {
        Some(values) => values[slot]
        None => @ir.hot_child_get(func, node_id, slot)
      }
      preludes.push(@ir.hot_build_local_set(func, locals[slot], payload_id))
    }
    let tuple_id = if tuple_values is Some(_) {
      @ir.hot_child_get(func, node_id, 0)
    } else {
      -1
    }
    ignore(@ir.hot_replace_child_span(func, node_id, []))
    if tuple_id >= 0 {
      pass_delete_detached_nodes(ctx, func, [tuple_id])
    }
    return true
  }
  if @ir.hot_label_branch_arity(func, label_id) != 1 ||
    target_types.length() != 1 ||
    value_types.length() != 1 ||
    target_types[0] != value_types[0] ||
    !flatten_value_type_is_defaultable(target_types[0]) ||
    !flatten_rewrite_target_can_route_scalar_branches(
      func,
      state,
      label_id,
      target_types[0],
    ) {
    return false
  }
  let locals = match
    flatten_ensure_label_temps(func, state, label_id, target_types) {
    Some(locals) => locals
    None => return false
  }
  preludes.push(@ir.hot_build_local_set(func, locals[0], value_id))
  ignore(@ir.hot_replace_child_span(func, node_id, []))
  true
}

///|
fn flatten_replace_cached_flowing_value_uses(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  branch_id : Int,
  value_id : Int,
  local_id : Int,
) -> Bool {
  let sites = match
    flatten_rewrite_scalar_br_if_flow_sites(func, state, branch_id, value_id) {
    Some(sites) => sites
    None => return false
  }
  if sites.is_empty() {
    return false
  }
  let replacement = @ir.hot_build_local_get(func, local_id)
  for site = 0; site < sites.length(); site = site + 2 {
    let parent_id = sites[site]
    let slot = sites[site + 1]
    if parent_id < 0 {
      @ir.hot_root_set(func, slot, replacement)
    } else {
      @ir.hot_child_set(func, parent_id, slot, replacement)
    }
  }
  if value_id >= 0 {
    flatten_scalar_flow_replacement_set(
      state.scalar_flow_replacement_entries,
      value_id,
      replacement,
    )
  }
  true
}

///|
fn flatten_replace_flowing_value_uses(
  func : @ir.HotFunc,
  branch_id : Int,
  value_id : Int,
  local_id : Int,
) -> Bool {
  let mut replacement = -1
  let mut replaced = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let child_count = @ir.hot_child_count(func, node_id)
    for slot = 0; slot < child_count; slot = slot + 1 {
      if node_id == branch_id && slot == 0 {
        continue
      }
      if @ir.hot_child_get(func, node_id, slot) == value_id {
        if replacement < 0 {
          replacement = @ir.hot_build_local_get(func, local_id)
        }
        @ir.hot_child_set(func, node_id, slot, replacement)
        replaced = true
      }
    }
  }
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    if @ir.hot_root_get(func, root_idx) == value_id {
      if replacement < 0 {
        replacement = @ir.hot_build_local_get(func, local_id)
      }
      @ir.hot_root_set(func, root_idx, replacement)
      replaced = true
    }
  }
  replaced
}

///|
fn flatten_try_route_multivalue_br_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  let child_count = @ir.hot_child_count(func, node_id)
  match branch.op {
    @ir.HotOp::BrIf if child_count > 2 => ()
    _ => return false
  }
  let payload_count = child_count - 1
  let label_id = branch.imm0
  if label_id < 0 || label_id >= state.label_temps.length() {
    return false
  }
  let label_kind = @ir.hot_label_kind(func, label_id)
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
  )
  match label_kind {
    @ir.HotLabelKind::TryLabel => {
      let try_id = @ir.hot_label_owner(func, label_id)
      if !flatten_multivalue_legacy_try_is_supported(
          func,
          try_id,
          state=Some(state),
        ) {
        return false
      }
      let flow = match
        flatten_rewrite_multivalue_try_br_if_flow_is_exact(
          func, state, try_id, node_id, target_types,
        ) {
        Some(flow) => flow
        None => return false
      }
      let locals = match
        flatten_ensure_label_temps(func, state, label_id, target_types) {
        Some(locals) => locals
        None => return false
      }
      let tuple_id = flow[0]
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let payload_id = if tuple_id >= 0 {
          @ir.hot_child_get(func, tuple_id, slot)
        } else {
          @ir.hot_child_get(func, node_id, slot)
        }
        preludes.push(@ir.hot_build_local_set(func, locals[slot], payload_id))
      }
      let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
      let region_ref = if flow[1] == 0 {
        @ir.hot_region_body_ref(func, try_id)
      } else {
        catch_ref
      }
      for offset = 0; offset < payload_count; offset = offset + 1 {
        let consumer_id = @ir.hot_region_get(
          func,
          region_ref,
          flow[2] + 1 + offset,
        )
        let payload_id = if tuple_id >= 0 {
          tuple_id
        } else {
          @ir.hot_child_get(func, node_id, payload_count - 1 - offset)
        }
        ignore(
          flatten_replace_multivalue_loop_br_if_consumer_payload(
            func,
            consumer_id,
            payload_id,
            locals[payload_count - 1 - offset],
          ),
        )
      }
      let condition_id = @ir.hot_child_get(func, node_id, payload_count)
      ignore(@ir.hot_replace_child_span(func, node_id, [condition_id]))
      if tuple_id >= 0 {
        pass_delete_detached_nodes(ctx, func, [tuple_id])
      }
      return true
    }
    @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel => ()
    _ => return false
  }
  if target_types.length() != payload_count ||
    @ir.hot_label_branch_arity(func, label_id) != payload_count ||
    !flatten_rewrite_multivalue_branch_target_is_supported(
      func, state, label_id, target_types, -1,
    ) {
    return false
  }
  let tuple_flow = flatten_rewrite_multivalue_tuple_br_if_flow(
    func, state, node_id, payload_count, target_types,
  )
  let flow_span = match tuple_flow {
    Some(flow) => [flow[1], flow[2]]
    None =>
      match
        flatten_rewrite_multivalue_br_if_flow_span(
          func, state, node_id, payload_count,
        ) {
        Some(flow_span) => flow_span
        None => return false
      }
  }
  let locals = match
    flatten_ensure_label_temps(func, state, label_id, target_types) {
    Some(locals) => locals
    None => return false
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = match tuple_flow {
      Some(flow) => @ir.hot_child_get(func, flow[0], slot)
      None => @ir.hot_child_get(func, node_id, slot)
    }
    preludes.push(@ir.hot_build_local_set(func, locals[slot], payload_id))
    @ir.hot_child_set(
      func,
      flow_span[0],
      flow_span[1] + slot,
      @ir.hot_build_local_get(func, locals[slot]),
    )
  }
  let condition_id = @ir.hot_child_get(func, node_id, payload_count)
  ignore(@ir.hot_replace_child_span(func, node_id, [condition_id]))
  match tuple_flow {
    Some(flow) => pass_delete_detached_nodes(ctx, func, [flow[0]])
    None => ()
  }
  true
}

///|
fn flatten_try_route_scalar_br_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  let child_count = @ir.hot_child_count(func, node_id)
  match branch.op {
    @ir.HotOp::BrIf if child_count > 1 => ()
    _ => return false
  }
  let payload_count = child_count - 1
  let label_id = branch.imm0
  if label_id < 0 || label_id >= state.label_temps.length() {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let value_types = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
  )
  match @ir.hot_label_kind(func, label_id) {
    @ir.HotLabelKind::LoopLabel => {
      let locals = state.label_temps[label_id]
      if locals.length() != payload_count {
        return false
      }
      let param_types : Array[@lib.ValType] = []
      for local_id in locals {
        match @ir.hot_local_type(func, local_id) {
          Some(value_type) => param_types.push(value_type)
          None => return false
        }
      }
      let tuple_flow = flatten_multivalue_tuple_loop_br_if_flow(
        func,
        @ir.hot_label_owner(func, label_id),
        node_id,
        param_types,
        use_counts=Some(state.use_def),
      )
      match tuple_flow {
        Some(flow) => {
          for slot = 0; slot < payload_count; slot = slot + 1 {
            preludes.push(
              @ir.hot_build_local_set(
                func,
                locals[slot],
                @ir.hot_child_get(func, flow[0], slot),
              ),
            )
          }
          let body_ref = @ir.hot_region_body_ref(
            func,
            @ir.hot_label_owner(func, label_id),
          )
          for offset = 0; offset < payload_count; offset = offset + 1 {
            let consumer_id = @ir.hot_region_get(
              func,
              body_ref,
              flow[1] + 1 + offset,
            )
            if !flatten_replace_multivalue_loop_br_if_consumer_payload(
                func,
                consumer_id,
                flow[0],
                locals[payload_count - 1 - offset],
              ) {
              return false
            }
          }
          let condition_id = @ir.hot_child_get(func, node_id, payload_count)
          ignore(@ir.hot_replace_child_span(func, node_id, [condition_id]))
          pass_delete_detached_nodes(ctx, func, [flow[0]])
          return true
        }
        None => ()
      }
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let payload_id = @ir.hot_child_get(func, node_id, slot)
        let payload_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, payload_id).ty,
        )
        if payload_types.length() != 1 ||
          @ir.hot_local_type(func, locals[slot]) != Some(payload_types[0]) {
          return false
        }
      }
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let payload_id = @ir.hot_child_get(func, node_id, slot)
        if payload_count == 1 {
          ignore(
            flatten_replace_cached_flowing_value_uses(
              func,
              state,
              node_id,
              payload_id,
              locals[slot],
            ),
          )
        } else {
          ignore(
            flatten_replace_flowing_value_uses(
              func,
              node_id,
              payload_id,
              locals[slot],
            ),
          )
        }
        preludes.push(@ir.hot_build_local_set(func, locals[slot], payload_id))
      }
      let condition_id = @ir.hot_child_get(func, node_id, payload_count)
      ignore(@ir.hot_replace_child_span(func, node_id, [condition_id]))
      return true
    }
    @ir.HotLabelKind::BlockLabel
    | @ir.HotLabelKind::IfLabel
    | @ir.HotLabelKind::TryLabel => if payload_count != 1 { return false }
    _ => return false
  }
  if @ir.hot_label_branch_arity(func, label_id) != 1 {
    return false
  }
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
  )
  if target_types.length() != 1 ||
    value_types.length() != 1 ||
    !flatten_value_type_is_defaultable(target_types[0]) ||
    !flatten_value_type_is_defaultable(value_types[0]) ||
    !flatten_rewrite_target_can_route_scalar_branches(
      func,
      state,
      label_id,
      target_types[0],
    ) {
    return false
  }
  let target_locals = match
    flatten_ensure_label_temps(func, state, label_id, target_types) {
    Some(locals) => locals
    None => return false
  }
  let local_id = target_locals[0]
  let flow_local = if target_types[0] == value_types[0] {
    local_id
  } else {
    @ir.hot_append_body_local(func, value_types[0])
  }
  ignore(
    flatten_replace_cached_flowing_value_uses(
      func, state, node_id, value_id, flow_local,
    ),
  )
  if flow_local == local_id {
    preludes.push(@ir.hot_build_local_set(func, local_id, value_id))
  } else {
    preludes.push(@ir.hot_build_local_set(func, flow_local, value_id))
    preludes.push(
      @ir.hot_build_local_set(
        func,
        local_id,
        @ir.hot_build_local_get(func, flow_local),
      ),
    )
  }
  let condition_id = @ir.hot_child_get(func, node_id, 1)
  ignore(@ir.hot_replace_child_span(func, node_id, [condition_id]))
  true
}

///|
fn flatten_unique_br_table_targets(
  func : @ir.HotFunc,
  table_id : Int,
) -> Array[Int] {
  let unique : Array[Int] = []
  for target in @ir.hot_branch_table_targets(func, table_id) {
    if !unique.contains(target) {
      unique.push(target)
    }
  }
  let default_target = @ir.hot_branch_table_default_target(func, table_id)
  if !unique.contains(default_target) {
    unique.push(default_target)
  }
  unique
}

///|
fn flatten_rewrite_br_table_target_locals(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  targets : Array[Int],
  payload_types : Array[@lib.ValType],
) -> Array[Array[Int]]? {
  if !state.rewrites_started || payload_types.is_empty() {
    return None
  }
  for target in targets {
    if target < 0 || target >= state.label_temps.length() {
      return None
    }
    let locals = state.label_temps[target]
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::LoopLabel =>
        if !flatten_label_temps_match_types(func, state, target, payload_types) {
          return None
        }
      @ir.HotLabelKind::BlockLabel
      | @ir.HotLabelKind::IfLabel
      | @ir.HotLabelKind::TryLabel =>
        if !locals.is_empty() &&
          !flatten_label_temps_match_types(func, state, target, payload_types) {
          return None
        }
      _ => return None
    }
  }
  let resolved : Array[Array[Int]] = []
  for target in targets {
    let locals = match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::LoopLabel => state.label_temps[target]
      _ =>
        match flatten_ensure_label_temps(func, state, target, payload_types) {
          Some(locals) => locals
          None => return None
        }
    }
    resolved.push(locals)
  }
  Some(resolved)
}

///|
fn flatten_tuple_mixed_try_table_is_supported(
  func : @ir.HotFunc,
  table_id : Int,
  payload_types : Array[@lib.ValType],
  targets : Array[Int],
  state? : FlattenRewriteState? = None,
) -> Bool {
  let tuple_values = flatten_multivalue_tuple_branch_payload_values(
    func,
    table_id,
    payload_types.length(),
    payload_types,
    state~,
  )
  if tuple_values is None || targets.length() <= 1 {
    return true
  }
  let mut try_label = -1
  let mut enclosing_control_count = 0
  for target in targets {
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::TryLabel => {
        if try_label >= 0 {
          return false
        }
        try_label = target
      }
      @ir.HotLabelKind::BlockLabel
      | @ir.HotLabelKind::IfLabel
      | @ir.HotLabelKind::LoopLabel =>
        enclosing_control_count = enclosing_control_count + 1
      _ => return false
    }
  }
  try_label >= 0 &&
  enclosing_control_count == targets.length() - 1 &&
  flatten_try_terminal_br_table_targets_label(
    func,
    table_id,
    try_label,
    payload_types.length(),
    true,
    state~,
  )
}

///|
fn flatten_try_route_br_table(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  let child_count = @ir.hot_child_count(func, node_id)
  match branch.op {
    @ir.HotOp::BrTable if child_count > 1 => ()
    _ => return false
  }
  let payload_count = child_count - 1
  let payload_types = match
    flatten_br_table_payload_types(
      func,
      node_id,
      payload_count,
      state=Some(state),
    ) {
    Some(payload_types) => payload_types
    None => return false
  }
  let tuple_values = flatten_rewrite_multivalue_tuple_branch_payload_values(
    func, state, node_id, payload_count, payload_types,
  )
  let targets = flatten_unique_br_table_targets(func, branch.imm0)
  if targets.length() == 0 {
    return false
  }
  if !flatten_tuple_mixed_try_table_is_supported(
      func,
      node_id,
      payload_types,
      targets,
      state=Some(state),
    ) {
    return false
  }
  for target in targets {
    if target < 0 || target >= state.label_temps.length() {
      return false
    }
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::LoopLabel => {
        let locals = state.label_temps[target]
        if locals.length() != payload_count {
          return false
        }
        for slot = 0; slot < payload_count; slot = slot + 1 {
          if @ir.hot_local_type(func, locals[slot]) != Some(payload_types[slot]) {
            return false
          }
        }
      }
      @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel => {
        if @ir.hot_label_branch_arity(func, target) != payload_count {
          return false
        }
        let target_types = @ir.hot_type_results(
          func,
          @ir.hot_label_result_type(func, target),
        )
        if target_types.length() != payload_count {
          return false
        }
        for slot = 0; slot < payload_count; slot = slot + 1 {
          if target_types[slot] != payload_types[slot] {
            return false
          }
        }
        if payload_count == 1 {
          if !flatten_rewrite_target_can_route_scalar_branches(
              func,
              state,
              target,
              payload_types[0],
            ) {
            return false
          }
        } else if !flatten_rewrite_multivalue_branch_target_is_supported(
            func, state, target, target_types, node_id,
          ) {
          return false
        }
      }
      @ir.HotLabelKind::TryLabel => {
        let target_types = @ir.hot_type_results(
          func,
          @ir.hot_label_result_type(func, target),
        )
        if target_types != payload_types ||
          @ir.hot_label_branch_arity(func, target) != payload_count {
          return false
        }
        let try_id = @ir.hot_label_owner(func, target)
        if payload_count == 1 {
          if !flatten_try_terminal_br_table_targets_label(
              func,
              node_id,
              target,
              1,
              true,
              state=Some(state),
            ) ||
            !flatten_scalar_legacy_try_is_supported(
              func,
              try_id,
              state=Some(state),
            ) {
            return false
          }
        } else if !flatten_multivalue_legacy_try_is_supported(
            func,
            try_id,
            state=Some(state),
          ) {
          return false
        }
      }
      _ => return false
    }
  }
  let target_locals = match
    flatten_rewrite_br_table_target_locals(func, state, targets, payload_types) {
    Some(target_locals) => target_locals
    None => return false
  }
  let value_locals : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = match tuple_values {
      Some(values) => values[slot]
      None => @ir.hot_child_get(func, node_id, slot)
    }
    let value_local = @ir.hot_append_body_local(func, payload_types[slot])
    value_locals.push(value_local)
    preludes.push(@ir.hot_build_local_set(func, value_local, value_id))
    state.terminal_payloads.push(value_id)
  }
  let suffix_nodes = flatten_try_table_dead_suffix_nodes(
    func,
    owner_region,
    node_id,
    state=Some(state),
  )
  match suffix_nodes {
    Some(nodes) if !nodes.is_empty() => {
      let root_count = @ir.hot_region_root_count(func, owner_region)
      for root_idx = 0; root_idx < root_count; root_idx = root_idx + 1 {
        if @ir.hot_region_get(func, owner_region, root_idx) != node_id ||
          root_idx + 1 >= root_count {
          continue
        }
        ignore(@ir.hot_region_truncate_suffix(func, owner_region, root_idx + 1))
        pass_mark_mutated(ctx, func)
        @ir.hot_delete_detached_nodes(func, nodes)
        break
      }
    }
    _ => ()
  }
  for target_slot = 0
      target_slot < target_locals.length()
      target_slot = target_slot + 1 {
    for slot = 0; slot < payload_count; slot = slot + 1 {
      preludes.push(
        @ir.hot_build_local_set(
          func,
          target_locals[target_slot][slot],
          @ir.hot_build_local_get(func, value_locals[slot]),
        ),
      )
    }
  }
  let selector_id = @ir.hot_child_get(func, node_id, payload_count)
  let tuple_id = if tuple_values is Some(_) {
    @ir.hot_child_get(func, node_id, 0)
  } else {
    -1
  }
  ignore(@ir.hot_replace_child_span(func, node_id, [selector_id]))
  if tuple_id >= 0 {
    pass_delete_detached_nodes(ctx, func, [tuple_id])
  }
  true
}

///|
fn flatten_node_is_admitted_terminal_control_effect(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef => true
    _ => false
  }
}

///|
fn flatten_place_unreachable_control_placeholder(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  preludes : Array[Int],
) -> Bool {
  if !flatten_node_is_admitted_terminal_control_effect(func, child_id) {
    return false
  }
  let mut already_sequenced = false
  for idx = 0; idx < state.sequenced_root_nodes.length(); idx = idx + 1 {
    if state.sequenced_root_holders[idx] == owner_region.holder &&
      state.sequenced_root_nodes[idx] == child_id {
      already_sequenced = true
    }
  }
  if !already_sequenced {
    preludes.push(child_id)
  }
  @ir.hot_child_set(func, parent_id, slot, @ir.hot_build_unreachable(func))
  true
}

///|
fn flatten_spill_scalar_operand(
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  preludes : Array[Int],
) -> Bool {
  let child = @ir.hot_node_get(func, child_id)
  let parent = @ir.hot_node_get(func, parent_id)
  let child_is_tee = match child.op {
    @ir.HotOp::LocalTee => true
    _ => false
  }
  let parent_allows_rich_value = match parent.op {
    @ir.HotOp::LocalSet => !flatten_op_is_control_structure(child.op)
    _ => false
  }
  if flatten_node_is_simple_operand(func, child_id) ||
    @ir.hot_node_kind_is_control(func, child_id) ||
    child_is_tee ||
    parent_allows_rich_value {
    return false
  }
  let result_types = @ir.hot_type_results(func, child.ty)
  if result_types.length() != 1 {
    return false
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  preludes.push(@ir.hot_build_local_set(func, local_id, child_id))
  @ir.hot_child_set(
    func,
    parent_id,
    slot,
    @ir.hot_build_local_get(func, local_id),
  )
  true
}

///|
fn flatten_try_lower_region_root_tee(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  root_idx : Int,
  node_id : Int,
) -> Int? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, node_id) == 1 => ()
    _ => return None
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let replacement = match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Unreachable => [value_id]
    _ =>
      [
        @ir.hot_build_local_set(func, node.imm0, value_id),
        @ir.hot_build_local_get(func, node.imm0),
      ]
  }
  let removed = pass_splice_region(
    ctx, func, region_ref, root_idx, 1, replacement,
  )
  pass_delete_detached_nodes(ctx, func, removed)
  Some(replacement.length())
}

///|
fn flatten_root_needs_sequence_tracking(
  state : FlattenRewriteState,
  node_id : Int,
) -> Bool {
  node_id >= 0 &&
  node_id < state.use_count_node_limit &&
  @ir.hot_node_use_count(state.use_def, node_id) > 1
}

///|
fn flatten_rewrite_region_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let preludes : Array[Int] = []
    if flatten_rewrite_node_operands(
        ctx, func, state, region_ref, node_id, preludes,
      ) {
      changed = true
    }
    let inserted = preludes.length()
    if inserted > 0 {
      ignore(pass_splice_region(ctx, func, region_ref, idx, 0, preludes))
      changed = true
    }
    let root_idx = idx + inserted
    if flatten_root_needs_sequence_tracking(state, node_id) {
      state.sequenced_root_holders.push(region_ref.holder)
      state.sequenced_root_nodes.push(node_id)
    }
    if state.terminal_payloads.contains(node_id) {
      ignore(pass_splice_region(ctx, func, region_ref, root_idx, 1, []))
      changed = true
      idx = root_idx
      continue
    }
    match
      flatten_try_lower_region_root_tee(
        ctx, func, region_ref, root_idx, node_id,
      ) {
      Some(replacement_count) => {
        changed = true
        idx = root_idx + replacement_count
      }
      None =>
        match
          flatten_try_route_multivalue_control_region_span(
            ctx, func, state, region_ref, root_idx, node_id,
          ) {
          Some(replacement_count) => {
            changed = true
            idx = root_idx + replacement_count
          }
          None =>
            match flatten_try_route_scalar_control(ctx, func, state, node_id) {
              Some(local_id) => {
                ignore(
                  pass_splice_region(ctx, func, region_ref, root_idx, 1, [
                    node_id,
                    @ir.hot_build_local_get(func, local_id),
                  ]),
                )
                changed = true
                idx = root_idx + 2
              }
              None => idx = root_idx + 1
            }
        }
    }
  }
  changed
}

///|
fn flatten_try_lower_tee_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  tee_id : Int,
  preludes : Array[Int],
) -> Bool {
  let tee = @ir.hot_node_get(func, tee_id)
  match tee.op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, tee_id) == 1 => ()
    _ => return false
  }
  let value_id = @ir.hot_child_get(func, tee_id, 0)
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Unreachable => {
      preludes.push(value_id)
      @ir.hot_child_set(func, parent_id, slot, @ir.hot_build_unreachable(func))
    }
    _ => {
      preludes.push(@ir.hot_build_local_set(func, tee.imm0, value_id))
      @ir.hot_child_set(
        func,
        parent_id,
        slot,
        @ir.hot_build_local_get(func, tee.imm0),
      )
    }
  }
  pass_delete_detached_nodes(ctx, func, [tee_id])
  true
}

///|
fn flatten_rewrite_operand_slot(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  parent_id : Int,
  slot : Int,
  preludes : Array[Int],
) -> Bool {
  let child_id = @ir.hot_child_get(func, parent_id, slot)
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  let mut changed = flatten_rewrite_node_operands(
    ctx, func, state, owner_region, child_id, preludes,
  )
  if flatten_try_lower_tee_operand(
      ctx, func, parent_id, slot, child_id, preludes,
    ) {
    return true
  }
  if flatten_try_route_multivalue_control_operand(
      ctx, func, state, parent_id, slot, child_id, preludes,
    ) {
    return true
  }
  match flatten_try_route_scalar_control(ctx, func, state, child_id) {
    Some(local_id) => {
      preludes.push(child_id)
      @ir.hot_child_set(
        func,
        parent_id,
        slot,
        @ir.hot_build_local_get(func, local_id),
      )
      changed = true
    }
    None =>
      if flatten_place_unreachable_control_placeholder(
          func, state, owner_region, parent_id, slot, child_id, preludes,
        ) {
        changed = true
      } else if flatten_spill_scalar_operand(
          func, parent_id, slot, child_id, preludes,
        ) {
        changed = true
      }
  }
  changed
}

///|
fn flatten_node_needs_postorder_branch_routing(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br => @ir.hot_child_count(func, node_id) > 0
    _ => false
  }
}

///|
fn flatten_rewrite_node_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut changed = false
  match node.op {
    @ir.HotOp::Block =>
      changed = flatten_rewrite_region_operands(
        ctx,
        func,
        state,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::Loop => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      let input_count = @ir.hot_label_branch_arity(func, label_id)
      if flatten_inputful_loop_is_supported(func, node_id, state=Some(state)) {
        for slot = 0; slot < input_count; slot = slot + 1 {
          let entry_id = @ir.hot_child_get(func, node_id, slot)
          if flatten_rewrite_node_operands(
              ctx, func, state, owner_region, entry_id, preludes,
            ) {
            changed = true
          }
        }
        flatten_prepare_inputful_scalar_loop(
          ctx, func, state, node_id, preludes,
        )
        changed = true
      } else {
        for slot = 0; slot < input_count; slot = slot + 1 {
          if flatten_rewrite_operand_slot(
              ctx, func, state, owner_region, node_id, slot, preludes,
            ) {
            changed = true
          }
        }
      }
      if flatten_rewrite_region_operands(
          ctx,
          func,
          state,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        changed = true
      }
    }
    @ir.HotOp::If => {
      if flatten_rewrite_operand_slot(
          ctx, func, state, owner_region, node_id, 0, preludes,
        ) {
        changed = true
      }
      if flatten_rewrite_region_operands(
          ctx,
          func,
          state,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if flatten_rewrite_region_operands(ctx, func, state, else_ref) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::Try => {
      if flatten_rewrite_region_operands(
          ctx,
          func,
          state,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) =>
          if flatten_rewrite_region_operands(ctx, func, state, catch_ref) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::TryTable => ()
    @ir.HotOp::BrIf if @ir.hot_child_count(func, node_id) > 1 => {
      let payload_count = @ir.hot_child_count(func, node_id) - 1
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let payload_id = @ir.hot_child_get(func, node_id, slot)
        if flatten_rewrite_node_operands(
            ctx, func, state, owner_region, payload_id, preludes,
          ) {
          changed = true
        }
      }
      if flatten_try_route_multivalue_br_if(ctx, func, state, node_id, preludes) {
        changed = true
      }
      if flatten_try_route_scalar_br_if(ctx, func, state, node_id, preludes) {
        changed = true
      }
      if flatten_rewrite_operand_slot(
          ctx, func, state, owner_region, node_id, 0, preludes,
        ) {
        changed = true
      }
      return changed
    }
    @ir.HotOp::BrTable if @ir.hot_child_count(func, node_id) > 1 => {
      let payload_count = @ir.hot_child_count(func, node_id) - 1
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let payload_id = @ir.hot_child_get(func, node_id, slot)
        if flatten_rewrite_node_operands(
            ctx, func, state, owner_region, payload_id, preludes,
          ) {
          changed = true
        }
      }
      if flatten_try_route_br_table(
          ctx, func, state, owner_region, node_id, preludes,
        ) {
        changed = true
      }
      if flatten_rewrite_operand_slot(
          ctx, func, state, owner_region, node_id, 0, preludes,
        ) {
        changed = true
      }
      return changed
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        if flatten_rewrite_operand_slot(
            ctx, func, state, owner_region, node_id, slot, preludes,
          ) {
          changed = true
        }
      }
  }
  if flatten_node_needs_postorder_branch_routing(func, node_id) &&
    flatten_try_route_br(ctx, func, state, node_id, preludes) {
    changed = true
  }
  changed
}

///|
fn flatten_materialize_scalar_body_result(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let root_count = @ir.hot_root_count(func)
  if root_count == 0 {
    return false
  }
  let tail_id = @ir.hot_root_get(func, root_count - 1)
  let tail = @ir.hot_node_get(func, tail_id)
  match tail.op {
    @ir.HotOp::Return => return false
    _ => ()
  }
  if flatten_op_is_control_structure(tail.op) {
    return false
  }
  let result_types = @ir.hot_type_results(func, tail.ty)
  if result_types.length() != 1 {
    return false
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  let set_id = @ir.hot_build_local_set(func, local_id, tail_id)
  let get_id = @ir.hot_build_local_get(func, local_id)
  let return_id = @ir.hot_build_return(func, [get_id])
  ignore(
    pass_splice_region(ctx, func, @ir.HotRegionRef::root(), root_count - 1, 1, [
      set_id, return_id,
    ]),
  )
  true
}

///|
fn flatten_scalar_branch_payload_has_supported_origin(
  func : @ir.HotFunc,
  value_id : Int,
) -> Bool {
  if flatten_node_is_simple_operand(func, value_id) {
    return true
  }
  let value = @ir.hot_node_get(func, value_id)
  if @ir.hot_node_kind_is_control(func, value_id) {
    return false
  }
  match value.op {
    @ir.HotOp::LocalTee => return false
    _ => ()
  }
  let value_types = @ir.hot_type_results(func, value.ty)
  value_types.length() == 1 && flatten_value_type_is_defaultable(value_types[0])
}

///|
fn flatten_has_deferred_inputful_loop(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => ()
      _ => continue
    }
    let label_id = @ir.hot_control_node_label(func, node_id)
    if @ir.hot_label_branch_arity(func, label_id) > 0 &&
      !flatten_inputful_loop_is_supported(func, node_id, state=Some(state)) {
      return true
    }
  }
  false
}

///|
fn flatten_has_deferred_legacy_try(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Try => {
        let result_arity = @ir.hot_node_result_arity(func, node_id)
        if result_arity == 1 &&
          !flatten_scalar_legacy_try_is_supported(
            func,
            node_id,
            state=Some(state),
          ) {
          return true
        }
        if result_arity > 1 &&
          !flatten_multivalue_legacy_try_is_supported(
            func,
            node_id,
            state=Some(state),
          ) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn flatten_has_deferred_rich_branch_payload(
  func : @ir.HotFunc,
  state? : FlattenRewriteState? = None,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br => {
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count == 0 {
          continue
        }
        if child_count == 1 {
          if !flatten_scalar_branch_payload_has_supported_origin(
              func,
              @ir.hot_child_get(func, node_id, 0),
            ) {
            return true
          }
          continue
        }
        let label_id = node.imm0
        if label_id < 0 || label_id >= func.labels.length() {
          return true
        }
        match @ir.hot_label_kind(func, label_id) {
          @ir.HotLabelKind::LoopLabel => ()
          @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel => {
            let target_types = @ir.hot_type_results(
              func,
              @ir.hot_label_result_type(func, label_id),
            )
            if !flatten_multivalue_branch_target_is_supported(
                func,
                label_id,
                target_types,
                state~,
              ) {
              return true
            }
          }
          @ir.HotLabelKind::TryLabel =>
            if !flatten_multivalue_legacy_try_is_supported(
                func,
                @ir.hot_label_owner(func, label_id),
                state~,
              ) {
              return true
            }
          _ => return true
        }
        if child_count != @ir.hot_label_branch_arity(func, label_id) {
          return true
        }
        let target_types = match @ir.hot_label_kind(func, label_id) {
          @ir.HotLabelKind::LoopLabel =>
            match flatten_loop_label_param_types(func, label_id) {
              Some(param_types) => param_types
              None => return true
            }
          _ =>
            @ir.hot_type_results(
              func,
              @ir.hot_label_result_type(func, label_id),
            )
        }
        if flatten_multivalue_tuple_branch_payload_values(
            func,
            node_id,
            child_count,
            target_types,
            state~,
          )
          is None {
          for slot = 0; slot < child_count; slot = slot + 1 {
            if !flatten_scalar_branch_payload_has_supported_origin(
                func,
                @ir.hot_child_get(func, node_id, slot),
              ) {
              return true
            }
          }
        }
      }
      @ir.HotOp::BrIf => {
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count <= 1 {
          continue
        }
        if child_count == 2 {
          let value_id = @ir.hot_child_get(func, node_id, 0)
          if !flatten_scalar_branch_payload_has_supported_origin(func, value_id) ||
            flatten_scalar_br_if_flow_sites(func, node_id, value_id, state~)
            is None {
            return true
          }
          continue
        }
        let label_id = node.imm0
        if label_id < 0 || label_id >= func.labels.length() {
          return true
        }
        let payload_count = child_count - 1
        match @ir.hot_label_kind(func, label_id) {
          @ir.HotLabelKind::LoopLabel => {
            if payload_count != @ir.hot_label_branch_arity(func, label_id) {
              return true
            }
            let param_types = match
              flatten_loop_label_param_types(func, label_id) {
              Some(param_types) => param_types
              None => return true
            }
            if flatten_multivalue_tuple_loop_br_if_flow(
                func,
                @ir.hot_label_owner(func, label_id),
                node_id,
                param_types,
                use_counts=match state {
                  Some(state) => Some(state.use_def)
                  None => None
                },
              )
              is None {
              for slot = 0; slot < payload_count; slot = slot + 1 {
                if !flatten_scalar_branch_payload_has_supported_origin(
                    func,
                    @ir.hot_child_get(func, node_id, slot),
                  ) {
                  return true
                }
              }
            }
          }
          @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel => {
            let target_types = @ir.hot_type_results(
              func,
              @ir.hot_label_result_type(func, label_id),
            )
            if !flatten_multivalue_branch_target_is_supported(
                func,
                label_id,
                target_types,
                state~,
              ) {
              return true
            }
          }
          @ir.HotLabelKind::TryLabel =>
            if !flatten_multivalue_legacy_try_is_supported(
                func,
                @ir.hot_label_owner(func, label_id),
                state~,
              ) {
              return true
            }
          _ => return true
        }
      }
      @ir.HotOp::BrTable => {
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count <= 1 {
          continue
        }
        let payload_count = child_count - 1
        let payload_types = match
          flatten_br_table_payload_types(func, node_id, payload_count, state~) {
          Some(payload_types) => payload_types
          None => return true
        }
        let targets = flatten_unique_br_table_targets(func, node.imm0)
        if !flatten_tuple_mixed_try_table_is_supported(
            func,
            node_id,
            payload_types,
            targets,
            state~,
          ) {
          return true
        }
        if payload_count > 1 {
          for target in targets {
            if target < 0 || target >= func.labels.length() {
              return true
            }
            match @ir.hot_label_kind(func, target) {
              @ir.HotLabelKind::LoopLabel =>
                if @ir.hot_label_branch_arity(func, target) != payload_count {
                  return true
                }
              @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel => {
                let target_types = @ir.hot_type_results(
                  func,
                  @ir.hot_label_result_type(func, target),
                )
                if !flatten_multivalue_branch_target_is_supported_with_table(
                    func,
                    target,
                    target_types,
                    node_id,
                    state~,
                  ) {
                  return true
                }
              }
              @ir.HotLabelKind::TryLabel =>
                if !flatten_multivalue_legacy_try_is_supported(
                    func,
                    @ir.hot_label_owner(func, target),
                    state~,
                  ) {
                  return true
                }
              _ => return true
            }
          }
        }
      }
      _ => ()
    }
  }
  false
}

///|
priv enum FlattenRunAdmission {
  Admitted
  UpstreamHardUnsupported
  DeferredCatchPayloadRepair
  DeferredExceptionalTransferRepair
  DeferredInputfulLoop
  DeferredLegacyTry
  DeferredBranchPayload
}

///|
fn flatten_run_admission(
  func : @ir.HotFunc,
  report : FlattenFlatnessReport,
  state? : FlattenRewriteState? = None,
) -> FlattenRunAdmission {
  let analysis = match state {
    Some(state) => state
    None => FlattenRewriteState::new(func)
  }
  if report.unsupported_count > 0 {
    return FlattenRunAdmission::UpstreamHardUnsupported
  }
  if analysis.eh_repair_requirement.needs_catch_payload_tracking {
    return FlattenRunAdmission::DeferredCatchPayloadRepair
  }
  if analysis.eh_repair_requirement.needs_exceptional_transfer_repair {
    return FlattenRunAdmission::DeferredExceptionalTransferRepair
  }
  if flatten_has_deferred_inputful_loop(func, analysis) {
    return FlattenRunAdmission::DeferredInputfulLoop
  }
  if flatten_has_deferred_legacy_try(func, analysis) {
    return FlattenRunAdmission::DeferredLegacyTry
  }
  if flatten_has_deferred_rich_branch_payload(func, state=Some(analysis)) {
    return FlattenRunAdmission::DeferredBranchPayload
  }
  FlattenRunAdmission::Admitted
}

///|
pub fn flatten_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let before = flatten_classify_hot(func)
  let state = FlattenRewriteState::new(func)
  match flatten_run_admission(func, before, state=Some(state)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::UpstreamHardUnsupported
    | FlattenRunAdmission::DeferredCatchPayloadRepair
    | FlattenRunAdmission::DeferredExceptionalTransferRepair
    | FlattenRunAdmission::DeferredInputfulLoop
    | FlattenRunAdmission::DeferredLegacyTry
    | FlattenRunAdmission::DeferredBranchPayload =>
      return HotPassResult::unchanged()
  }
  state.rewrites_started = true
  let mut changed = flatten_rewrite_region_operands(
    ctx,
    func,
    state,
    @ir.HotRegionRef::root(),
  )
  if flatten_materialize_scalar_body_result(ctx, func) {
    changed = true
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
