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
fn flatten_classify_live_node(
  func : @ir.HotFunc,
  node_id : Int,
  report : FlattenFlatnessReport,
) -> Unit {
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
        let child = @ir.hot_node_get(func, @ir.hot_child_get(func, node_id, 0))
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
          !flatten_op_is_control_structure(@ir.hot_node_get(func, child_id).op)
        _ => false
      }
      if !local_set_value_is_allowed &&
        !flatten_node_is_simple_operand(func, child_id) {
        report.rich_operand_count += 1
      }
    }
  }
}

///|
fn flatten_classify_body_value_flow(
  func : @ir.HotFunc,
  report : FlattenFlatnessReport,
) -> Unit {
  let root_count = @ir.hot_root_count(func)
  if root_count > 0 {
    let tail = @ir.hot_root_get(func, root_count - 1)
    if @ir.hot_node_is_live(func, tail) &&
      @ir.hot_node_result_arity(func, tail) > 0 {
      report.body_value_flow_count = 1
    }
  }
}

///|
/// Classify the current HOT function without mutating it.
pub fn flatten_classify_hot(func : @ir.HotFunc) -> FlattenFlatnessReport {
  let report = FlattenFlatnessReport::empty()
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      flatten_classify_live_node(func, node_id, report)
    }
  }
  flatten_classify_body_value_flow(func, report)
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
fn flatten_record_label_branch_node(
  branch_nodes : Array[Array[Int]],
  last_recorded_node : Array[Int],
  label_id : Int,
  node_id : Int,
) -> Unit {
  if label_id >= 0 &&
    label_id < branch_nodes.length() &&
    label_id < last_recorded_node.length() &&
    last_recorded_node[label_id] != node_id {
    branch_nodes[label_id].push(node_id)
    last_recorded_node[label_id] = node_id
  }
}

///|
priv struct FlattenBrTableTargetsEntry {
  table_id : Int
  start : Int
  count : Int
}

///|
fn FlattenBrTableTargetsEntry::new(
  table_id : Int,
  start : Int,
  count : Int,
) -> FlattenBrTableTargetsEntry {
  { table_id, start, count }
}

///|
priv struct FlattenBrTableTargets {
  targets : Array[Int]
  start : Int
  count : Int
}

///|
fn FlattenBrTableTargets::new(
  targets : Array[Int],
  start : Int,
  count : Int,
) -> FlattenBrTableTargets {
  { targets, start, count }
}

///|
fn flatten_br_table_targets_entry_lower_bound(
  entries : Array[FlattenBrTableTargetsEntry],
  table_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].table_id < table_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_br_table_targets_entry_index(
  entries : Array[FlattenBrTableTargetsEntry],
  table_id : Int,
) -> Int {
  let index = flatten_br_table_targets_entry_lower_bound(entries, table_id)
  if index < entries.length() && entries[index].table_id == table_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_record_generation_target(
  targets : Array[Int],
  marks : Array[Int],
  epoch : Int,
  target : Int,
) -> Bool {
  if target < 0 || target >= marks.length() || marks[target] == epoch {
    return false
  }
  marks[target] = epoch
  targets.push(target)
  true
}

///|
fn flatten_index_br_table_targets(
  func : @ir.HotFunc,
  table_id : Int,
  entries : Array[FlattenBrTableTargetsEntry],
  targets : Array[Int],
  marks : Array[Int],
  epoch : Int,
) -> Unit {
  if flatten_br_table_targets_entry_index(entries, table_id) >= 0 {
    return
  }
  let start = targets.length()
  for target in @ir.hot_branch_table_targets(func, table_id) {
    ignore(flatten_record_generation_target(targets, marks, epoch, target))
  }
  ignore(
    flatten_record_generation_target(
      targets,
      marks,
      epoch,
      @ir.hot_branch_table_default_target(func, table_id),
    ),
  )
  let entry = FlattenBrTableTargetsEntry::new(
    table_id,
    start,
    targets.length() - start,
  )
  entries.insert(
    flatten_br_table_targets_entry_lower_bound(entries, table_id),
    entry,
  )
}

///|
fn flatten_record_structural_parent_region(
  func : @ir.HotFunc,
  owner_id : Int,
  region_ref : @ir.HotRegionRef,
  direct_parent : Array[Int],
) -> Unit {
  for root_idx = 0
      root_idx < @ir.hot_region_root_count(func, region_ref)
      root_idx = root_idx + 1 {
    let child_id = @ir.hot_region_get(func, region_ref, root_idx)
    if child_id < 0 || child_id >= direct_parent.length() {
      continue
    }
    if direct_parent[child_id] == -1 || direct_parent[child_id] == owner_id {
      direct_parent[child_id] = owner_id
    } else {
      direct_parent[child_id] = -2
    }
  }
}

///|
fn flatten_build_structural_direct_parent(func : @ir.HotFunc) -> Array[Int] {
  let direct_parent = Array::make(@ir.hot_node_count(func), -1)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block => {
        let label_id = @ir.hot_control_node_label(func, node_id)
        if label_id >= 0 && label_id < func.labels.length() {
          match @ir.hot_label_kind(func, label_id) {
            @ir.HotLabelKind::BlockLabel =>
              flatten_record_structural_parent_region(
                func,
                node_id,
                @ir.hot_region_body_ref(func, node_id),
                direct_parent,
              )
            _ => ()
          }
        }
      }
      @ir.HotOp::Loop =>
        flatten_record_structural_parent_region(
          func,
          node_id,
          @ir.hot_region_body_ref(func, node_id),
          direct_parent,
        )
      @ir.HotOp::If => {
        flatten_record_structural_parent_region(
          func,
          node_id,
          @ir.hot_region_then_ref(func, node_id),
          direct_parent,
        )
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            flatten_record_structural_parent_region(
              func, node_id, else_ref, direct_parent,
            )
          None => ()
        }
      }
      @ir.HotOp::Try => {
        flatten_record_structural_parent_region(
          func,
          node_id,
          @ir.hot_region_body_ref(func, node_id),
          direct_parent,
        )
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            flatten_record_structural_parent_region(
              func, node_id, catch_ref, direct_parent,
            )
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        flatten_record_structural_parent_region(
          func,
          node_id,
          @ir.hot_region_body_ref(func, node_id),
          direct_parent,
        )
        flatten_record_structural_parent_region(
          func,
          node_id,
          @ir.hot_region_catch_list_ref(func, node_id),
          direct_parent,
        )
      }
      _ => ()
    }
  }
  direct_parent
}

///|
priv struct FlattenPreMutationNodeIndex {
  label_branch_nodes : Array[Array[Int]]
  br_table_target_entries : Array[FlattenBrTableTargetsEntry]
  br_table_targets : Array[Int]
  loop_nodes : Array[Int]
  try_nodes : Array[Int]
  branch_payload_nodes : Array[Int]
  eh_repair_requirement : FlattenEhRepairRequirement
  flatness_report : FlattenFlatnessReport
}

///|
fn flatten_build_pre_mutation_node_index(
  func : @ir.HotFunc,
) -> FlattenPreMutationNodeIndex {
  let branch_nodes : Array[Array[Int]] = []
  let last_recorded_node : Array[Int] = []
  for label_idx = 0; label_idx < func.labels.length(); label_idx = label_idx + 1 {
    branch_nodes.push([])
    last_recorded_node.push(-1)
  }
  let br_table_target_entries : Array[FlattenBrTableTargetsEntry] = []
  let br_table_targets : Array[Int] = []
  let table_target_marks = Array::make(func.labels.length(), 0)
  let mut next_table_target_mark = 1
  let loop_nodes : Array[Int] = []
  let try_nodes : Array[Int] = []
  let branch_payload_nodes : Array[Int] = []
  let eh_repair_requirement = FlattenEhRepairRequirement::empty()
  let flatness_report = FlattenFlatnessReport::empty()
  let record = fn(label_id : Int, node_id : Int) {
    flatten_record_label_branch_node(
      branch_nodes, last_recorded_node, label_id, node_id,
    )
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    flatten_classify_live_node(func, node_id, flatness_report)
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Loop => loop_nodes.push(node_id)
      @ir.HotOp::Try => try_nodes.push(node_id)
      @ir.HotOp::Br | @ir.HotOp::BrIf => {
        branch_payload_nodes.push(node_id)
        record(node.imm0, node_id)
      }
      @ir.HotOp::BrTable => {
        branch_payload_nodes.push(node_id)
        flatten_index_br_table_targets(
          func,
          node.imm0,
          br_table_target_entries,
          br_table_targets,
          table_target_marks,
          next_table_target_mark,
        )
        next_table_target_mark = next_table_target_mark + 1
        record(@ir.hot_branch_table_default_target(func, node.imm0), node_id)
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          record(label_id, node_id)
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail => record(node.imm0, node_id)
      @ir.HotOp::Delegate => {
        record(node.imm0, node_id)
        eh_repair_requirement.needs_exceptional_transfer_repair = true
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
      @ir.HotOp::Catch | @ir.HotOp::CatchAll =>
        eh_repair_requirement.needs_catch_payload_tracking = true
      @ir.HotOp::Rethrow =>
        eh_repair_requirement.needs_exceptional_transfer_repair = true
      _ => ()
    }
  }
  flatten_classify_body_value_flow(func, flatness_report)
  {
    label_branch_nodes: branch_nodes,
    br_table_target_entries,
    br_table_targets,
    loop_nodes,
    try_nodes,
    branch_payload_nodes,
    eh_repair_requirement,
    flatness_report,
  }
}

///|
fn flatten_build_label_branch_nodes(func : @ir.HotFunc) -> Array[Array[Int]] {
  flatten_build_pre_mutation_node_index(func).label_branch_nodes
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
fn flatten_br_if_flow_entry_lower_bound(
  entries : Array[FlattenBrIfFlowEntry],
  branch_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].branch_id < branch_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_br_if_flow_entry_index(
  entries : Array[FlattenBrIfFlowEntry],
  branch_id : Int,
) -> Int {
  let index = flatten_br_if_flow_entry_lower_bound(entries, branch_id)
  if index < entries.length() && entries[index].branch_id == branch_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_br_if_flow_entry_set(
  entries : Array[FlattenBrIfFlowEntry],
  entry : FlattenBrIfFlowEntry,
) -> Unit {
  let index = flatten_br_if_flow_entry_lower_bound(entries, entry.branch_id)
  if index >= entries.length() || entries[index].branch_id != entry.branch_id {
    entries.insert(index, entry)
  }
}

///|
fn flatten_scalar_br_if_flow_entry_lower_bound(
  entries : Array[FlattenScalarBrIfFlowEntry],
  branch_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].branch_id < branch_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_scalar_br_if_flow_entry_index(
  entries : Array[FlattenScalarBrIfFlowEntry],
  branch_id : Int,
) -> Int {
  let index = flatten_scalar_br_if_flow_entry_lower_bound(entries, branch_id)
  if index < entries.length() && entries[index].branch_id == branch_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_scalar_br_if_flow_entry_set(
  entries : Array[FlattenScalarBrIfFlowEntry],
  entry : FlattenScalarBrIfFlowEntry,
) -> Unit {
  let index = flatten_scalar_br_if_flow_entry_lower_bound(
    entries,
    entry.branch_id,
  )
  if index >= entries.length() || entries[index].branch_id != entry.branch_id {
    entries.insert(index, entry)
  }
}

///|
fn flatten_scalar_flow_replacement_entry_lower_bound(
  entries : Array[FlattenScalarFlowReplacementEntry],
  value_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].value_id < value_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_scalar_flow_replacement(
  entries : Array[FlattenScalarFlowReplacementEntry],
  value_id : Int,
) -> Int {
  let index = flatten_scalar_flow_replacement_entry_lower_bound(
    entries, value_id,
  )
  if index < entries.length() && entries[index].value_id == value_id {
    entries[index].replacement_id
  } else {
    -1
  }
}

///|
fn flatten_scalar_flow_replacement_set(
  entries : Array[FlattenScalarFlowReplacementEntry],
  value_id : Int,
  replacement_id : Int,
) -> Unit {
  let index = flatten_scalar_flow_replacement_entry_lower_bound(
    entries, value_id,
  )
  let entry = FlattenScalarFlowReplacementEntry::new(value_id, replacement_id)
  if index < entries.length() && entries[index].value_id == value_id {
    entries[index] = entry
  } else {
    entries.insert(index, entry)
  }
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
priv struct FlattenInputfulLoopSupportEntry {
  loop_id : Int
  supported : Bool
}

///|
fn FlattenInputfulLoopSupportEntry::new(
  loop_id : Int,
  supported : Bool,
) -> FlattenInputfulLoopSupportEntry {
  { loop_id, supported }
}

///|
fn flatten_dead_suffix_entry_lower_bound(
  entries : Array[FlattenDeadSuffixEntry],
  table_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].table_id < table_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_dead_suffix_entry_index(
  entries : Array[FlattenDeadSuffixEntry],
  table_id : Int,
) -> Int {
  let index = flatten_dead_suffix_entry_lower_bound(entries, table_id)
  if index < entries.length() && entries[index].table_id == table_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_dead_suffix_entry_set(
  entries : Array[FlattenDeadSuffixEntry],
  entry : FlattenDeadSuffixEntry,
) -> Unit {
  let index = flatten_dead_suffix_entry_lower_bound(entries, entry.table_id)
  if index >= entries.length() || entries[index].table_id != entry.table_id {
    entries.insert(index, entry)
  }
}

///|
fn flatten_terminal_table_entry_lower_bound(
  entries : Array[FlattenTerminalTableEntry],
  node_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].node_id < node_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_terminal_table_entry_index(
  entries : Array[FlattenTerminalTableEntry],
  node_id : Int,
) -> Int {
  let index = flatten_terminal_table_entry_lower_bound(entries, node_id)
  if index < entries.length() && entries[index].node_id == node_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_terminal_table_entry_set(
  entries : Array[FlattenTerminalTableEntry],
  entry : FlattenTerminalTableEntry,
) -> Unit {
  let index = flatten_terminal_table_entry_lower_bound(entries, entry.node_id)
  if index >= entries.length() || entries[index].node_id != entry.node_id {
    entries.insert(index, entry)
  }
}

///|
fn flatten_scalar_try_entry_lower_bound(
  entries : Array[FlattenScalarTryEntry],
  try_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].try_id < try_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_scalar_try_entry_index(
  entries : Array[FlattenScalarTryEntry],
  try_id : Int,
) -> Int {
  let index = flatten_scalar_try_entry_lower_bound(entries, try_id)
  if index < entries.length() && entries[index].try_id == try_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_scalar_try_entry_set(
  entries : Array[FlattenScalarTryEntry],
  try_id : Int,
  supported : Bool,
) -> Unit {
  let index = flatten_scalar_try_entry_lower_bound(entries, try_id)
  let entry = FlattenScalarTryEntry::new(try_id, supported)
  if index < entries.length() && entries[index].try_id == try_id {
    entries[index] = entry
  } else {
    entries.insert(index, entry)
  }
}

///|
fn flatten_inputful_loop_support_entry_lower_bound(
  entries : Array[FlattenInputfulLoopSupportEntry],
  loop_id : Int,
) -> Int {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if entries[middle].loop_id < loop_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_inputful_loop_support_entry_index(
  entries : Array[FlattenInputfulLoopSupportEntry],
  loop_id : Int,
) -> Int {
  let index = flatten_inputful_loop_support_entry_lower_bound(entries, loop_id)
  if index < entries.length() && entries[index].loop_id == loop_id {
    index
  } else {
    -1
  }
}

///|
fn flatten_inputful_loop_support_entry_set(
  entries : Array[FlattenInputfulLoopSupportEntry],
  loop_id : Int,
  supported : Bool,
) -> Unit {
  let index = flatten_inputful_loop_support_entry_lower_bound(entries, loop_id)
  if index >= entries.length() || entries[index].loop_id != loop_id {
    entries.insert(
      index,
      FlattenInputfulLoopSupportEntry::new(loop_id, supported),
    )
  }
}

///|
fn flatten_terminal_payload_lower_bound(
  payloads : Array[Int],
  node_id : Int,
) -> Int {
  let mut low = 0
  let mut high = payloads.length()
  while low < high {
    let middle = low + (high - low) / 2
    if payloads[middle] < node_id {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_terminal_payload_contains(
  payloads : Array[Int],
  node_id : Int,
) -> Bool {
  let index = flatten_terminal_payload_lower_bound(payloads, node_id)
  index < payloads.length() && payloads[index] == node_id
}

///|
fn flatten_terminal_payload_record(
  payloads : Array[Int],
  node_id : Int,
) -> Bool {
  if node_id < 0 {
    return false
  }
  let index = flatten_terminal_payload_lower_bound(payloads, node_id)
  if index < payloads.length() && payloads[index] == node_id {
    return false
  }
  payloads.insert(index, node_id)
  true
}

///|
fn flatten_sequenced_root_lower_bound(
  holders : Array[Int],
  nodes : Array[Int],
  holder : Int,
  node_id : Int,
) -> Int {
  let mut low = 0
  let mut high = if holders.length() < nodes.length() {
    holders.length()
  } else {
    nodes.length()
  }
  while low < high {
    let middle = low + (high - low) / 2
    if holders[middle] < holder ||
      (holders[middle] == holder && nodes[middle] < node_id) {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low
}

///|
fn flatten_sequenced_root_contains(
  holders : Array[Int],
  nodes : Array[Int],
  holder : Int,
  node_id : Int,
) -> Bool {
  if holder < 0 || node_id < 0 || holders.length() != nodes.length() {
    return false
  }
  let index = flatten_sequenced_root_lower_bound(
    holders, nodes, holder, node_id,
  )
  index < nodes.length() && holders[index] == holder && nodes[index] == node_id
}

///|
fn flatten_sequenced_root_record(
  holders : Array[Int],
  nodes : Array[Int],
  holder : Int,
  node_id : Int,
) -> Bool {
  if holder < 0 || node_id < 0 || holders.length() != nodes.length() {
    return false
  }
  let index = flatten_sequenced_root_lower_bound(
    holders, nodes, holder, node_id,
  )
  if index < nodes.length() &&
    holders[index] == holder &&
    nodes[index] == node_id {
    return false
  }
  holders.insert(index, holder)
  nodes.insert(index, node_id)
  true
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
  br_table_target_entries : Array[FlattenBrTableTargetsEntry]
  br_table_targets : Array[Int]
  direct_parent : Array[Int]
  mut direct_parent_built : Bool
  node_marks : Array[Int]
  mut next_node_mark : Int
  prelude_buffers : Array[Array[Int]]
  mut prelude_depth : Int
  type_result_cache : Array[Array[@lib.ValType]?]
  loop_nodes : Array[Int]
  try_nodes : Array[Int]
  branch_payload_nodes : Array[Int]
  use_def : @ir.HotNodeUseCounts
  use_count_node_limit : Int
  tuple_br_if_flow_entries : Array[FlattenBrIfFlowEntry]
  multivalue_br_if_flow_entries : Array[FlattenBrIfFlowEntry]
  scalar_br_if_flow_entries : Array[FlattenScalarBrIfFlowEntry]
  scalar_flow_replacement_entries : Array[FlattenScalarFlowReplacementEntry]
  dead_suffix_entries : Array[FlattenDeadSuffixEntry]
  terminal_table_entries : Array[FlattenTerminalTableEntry]
  scalar_try_entries : Array[FlattenScalarTryEntry]
  inputful_loop_support_entries : Array[FlattenInputfulLoopSupportEntry]
  flatness_report : FlattenFlatnessReport
  mut rewrites_started : Bool
}

///|
fn FlattenRewriteState::new(func : @ir.HotFunc) -> FlattenRewriteState {
  let label_temps : Array[Array[Int]] = []
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    label_temps.push([])
  }
  let node_index = flatten_build_pre_mutation_node_index(func)
  let label_branch_nodes = node_index.label_branch_nodes
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
    eh_repair_requirement: node_index.eh_repair_requirement,
    label_used,
    label_branch_nodes,
    br_table_target_entries: node_index.br_table_target_entries,
    br_table_targets: node_index.br_table_targets,
    direct_parent: [],
    direct_parent_built: false,
    node_marks: [],
    next_node_mark: 1,
    prelude_buffers: [],
    prelude_depth: 0,
    type_result_cache: [],
    loop_nodes: node_index.loop_nodes,
    try_nodes: node_index.try_nodes,
    branch_payload_nodes: node_index.branch_payload_nodes,
    use_def: flatten_build_node_use_counts(func),
    use_count_node_limit: @ir.hot_node_count(func),
    tuple_br_if_flow_entries: [],
    multivalue_br_if_flow_entries: [],
    scalar_br_if_flow_entries: [],
    scalar_flow_replacement_entries: [],
    dead_suffix_entries: [],
    terminal_table_entries: [],
    scalar_try_entries: [],
    inputful_loop_support_entries: [],
    flatness_report: node_index.flatness_report,
    rewrites_started: false,
  }
}

///|
fn flatten_take_node_mark(state : FlattenRewriteState) -> Int {
  while state.node_marks.length() < state.use_count_node_limit {
    state.node_marks.push(0)
  }
  if state.next_node_mark >= 2147483646 {
    for node_id = 0; node_id < state.node_marks.length(); node_id = node_id + 1 {
      state.node_marks[node_id] = 0
    }
    state.next_node_mark = 1
  }
  let mark = state.next_node_mark
  state.next_node_mark = state.next_node_mark + 1
  mark
}

///|
fn flatten_ensure_direct_parent(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
) -> Bool {
  if state.direct_parent_built {
    return true
  }
  if state.rewrites_started {
    return false
  }
  state.direct_parent.append(flatten_build_structural_direct_parent(func))
  state.direct_parent_built = true
  true
}

///|
fn flatten_prelude_buffer(
  state : FlattenRewriteState,
  depth : Int,
) -> Array[Int] {
  while state.prelude_buffers.length() <= depth {
    state.prelude_buffers.push([])
  }
  let buffer = state.prelude_buffers[depth]
  buffer.clear()
  buffer
}

///|
fn flatten_type_results(
  func : @ir.HotFunc,
  type_id : Int,
  state? : FlattenRewriteState? = None,
) -> Array[@lib.ValType] {
  match state {
    Some(state) => {
      if type_id < 0 {
        return []
      }
      while state.type_result_cache.length() <= type_id {
        state.type_result_cache.push(None)
      }
      match state.type_result_cache[type_id] {
        Some(results) => results
        None => {
          let results = @ir.hot_type_results(func, type_id)
          state.type_result_cache[type_id] = Some(results)
          results
        }
      }
    }
    None => @ir.hot_type_results(func, type_id)
  }
}

///|
fn flatten_single_result_type(
  func : @ir.HotFunc,
  type_id : Int,
) -> @lib.ValType? {
  match @ir.hot_type_get(func, type_id) {
    @ir.HotTypeInfo::Value(value_type) => Some(value_type)
    @ir.HotTypeInfo::BlockResult(@lib.ValTypeBlockType(value_type)) =>
      Some(value_type)
    @ir.HotTypeInfo::BlockResultResolved(_, _, results)
    | @ir.HotTypeInfo::Results(results) =>
      if results.length() == 1 {
        Some(results[0])
      } else {
        None
      }
    _ => None
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
  state? : FlattenRewriteState? = None,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if result_types.length() <= 1 || root_count < result_types.length() {
    return false
  }
  let tail_start = root_count - result_types.length()
  for slot = 0; slot < result_types.length(); slot = slot + 1 {
    let value_id = @ir.hot_region_get(func, region_ref, tail_start + slot)
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
  state? : FlattenRewriteState? = None,
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
      flatten_type_results(func, tuple.ty, state~) == result_types &&
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
  if flatten_type_results(func, tuple.ty, state~) != result_types ||
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
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
  if flatten_type_results(func, tuple.ty, state~) != result_types ||
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
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
  let result_types = flatten_type_results(func, block.ty, state=Some(state))
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
  if !flatten_multivalue_region_tail_matches_types(
      func,
      body_ref,
      result_types,
      state=Some(state),
    ) &&
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
  let result_types = flatten_type_results(func, if_node.ty, state=Some(state))
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
        func,
        region_ref,
        result_types,
        state=Some(state),
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

///| Walk frozen direct structural parent links from the legacy try.

///|
/// The parent population is built once per flatten run. Query-local target and
/// cycle checks reuse generation marks instead of allocating node-sized arrays.
fn flatten_direct_enclosing_target_controls(
  func : @ir.HotFunc,
  inner_id : Int,
  target_controls : Array[Int],
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  if inner_id < 0 || inner_id >= @ir.hot_node_count(func) {
    return None
  }
  if target_controls.is_empty() {
    return Some([])
  }
  let (direct_parent, marks, target_mark, chain_mark) = match state {
    Some(state) => {
      if !flatten_ensure_direct_parent(func, state) {
        return None
      }
      (
        state.direct_parent,
        state.node_marks,
        flatten_take_node_mark(state),
        flatten_take_node_mark(state),
      )
    }
    None =>
      (
        flatten_build_structural_direct_parent(func),
        Array::make(@ir.hot_node_count(func), 0),
        1,
        2,
      )
  }
  for owner_id in target_controls {
    if owner_id < 0 ||
      owner_id >= direct_parent.length() ||
      !@ir.hot_node_is_live(func, owner_id) ||
      marks[owner_id] == target_mark ||
      flatten_direct_target_control_regions(func, owner_id) is None {
      return None
    }
    marks[owner_id] = target_mark
  }
  let chain : Array[Int] = []
  let mut current = inner_id
  while chain.length() < target_controls.length() {
    if current < 0 || current >= direct_parent.length() {
      return None
    }
    let parent = direct_parent[current]
    if parent < 0 || parent >= marks.length() || marks[parent] != target_mark {
      return None
    }
    marks[parent] = chain_mark
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
fn flatten_try_table_dead_suffix_drop_const_is_supported(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  drop_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, drop_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, drop_id) != 1 ||
    @ir.hot_node_use_count(use_def, drop_id) != 1 {
    return false
  }
  let value_id = @ir.hot_child_get(func, drop_id, 0)
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Const => @ir.hot_node_use_count(use_def, value_id) == 1
    _ => false
  }
}

///|
fn flatten_try_table_dead_suffix_control_label_is_unreferenced(
  func : @ir.HotFunc,
  node_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let label_id = @ir.hot_control_node_label(func, node_id)
  if !@ir.hot_label_is_live(func, label_id) ||
    @ir.hot_label_owner(func, label_id) != node_id {
    return false
  }
  let branch_nodes = match state {
    Some(state) => state.label_branch_nodes[label_id]
    None => flatten_build_label_branch_nodes(func)[label_id]
  }
  branch_nodes.is_empty()
}

///|
fn flatten_try_table_dead_suffix_structured_block_is_supported(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  block_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, block_id) != 0 ||
    @ir.hot_child_count(func, block_id) != 1 ||
    @ir.hot_node_use_count(use_def, block_id) != 1 {
    return false
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  match @ir.hot_label_kind(func, label_id) {
    @ir.HotLabelKind::BlockLabel => ()
    _ => return false
  }
  if !flatten_try_table_dead_suffix_control_label_is_unreferenced(
      func,
      block_id,
      state~,
    ) {
    return false
  }
  flatten_try_table_dead_suffix_drop_const_is_supported(
    func,
    use_def,
    @ir.hot_child_get(func, block_id, 0),
  )
}

///|
fn flatten_try_table_dead_suffix_if_region_is_supported(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  region : @ir.HotRegionRef,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let holder = region.holder
  match @ir.hot_node_get(func, holder).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, holder) != 0 ||
    @ir.hot_node_use_count(use_def, holder) != 1 ||
    @ir.hot_region_root_count(func, region) != 1 ||
    !flatten_try_table_dead_suffix_control_label_is_unreferenced(
      func,
      holder,
      state~,
    ) {
    return false
  }
  match @ir.hot_label_kind(func, @ir.hot_control_node_label(func, holder)) {
    @ir.HotLabelKind::RegionLabel => ()
    _ => return false
  }
  flatten_try_table_dead_suffix_drop_const_is_supported(
    func,
    use_def,
    @ir.hot_region_get(func, region, 0),
  )
}

///|
fn flatten_try_table_dead_suffix_structured_if_is_supported(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  if_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, if_id) != 0 ||
    @ir.hot_child_count(func, if_id) != 3 ||
    @ir.hot_node_use_count(use_def, if_id) != 1 ||
    !flatten_try_table_dead_suffix_control_label_is_unreferenced(
      func,
      if_id,
      state~,
    ) {
    return false
  }
  match @ir.hot_label_kind(func, @ir.hot_control_node_label(func, if_id)) {
    @ir.HotLabelKind::IfLabel => ()
    _ => return false
  }
  let condition_id = @ir.hot_child_get(func, if_id, 0)
  match @ir.hot_node_get(func, condition_id).op {
    @ir.HotOp::Const => ()
    _ => return false
  }
  if @ir.hot_node_use_count(use_def, condition_id) != 1 ||
    !flatten_try_table_dead_suffix_if_region_is_supported(
      func,
      use_def,
      @ir.hot_region_then_ref(func, if_id),
      state~,
    ) {
    return false
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(region) =>
      flatten_try_table_dead_suffix_if_region_is_supported(
        func,
        use_def,
        region,
        state~,
      )
    None => false
  }
}

///|
fn flatten_try_table_dead_suffix_structured_loop_is_supported(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  loop_id : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
  match @ir.hot_node_get(func, loop_id).op {
    @ir.HotOp::Loop => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, loop_id) != 0 ||
    @ir.hot_child_count(func, loop_id) != 1 ||
    @ir.hot_node_use_count(use_def, loop_id) != 1 ||
    !flatten_try_table_dead_suffix_control_label_is_unreferenced(
      func,
      loop_id,
      state~,
    ) {
    return false
  }
  let label_id = @ir.hot_control_node_label(func, loop_id)
  match @ir.hot_label_kind(func, label_id) {
    @ir.HotLabelKind::LoopLabel => ()
    _ => return false
  }
  if @ir.hot_label_branch_arity(func, label_id) != 0 {
    return false
  }
  flatten_try_table_dead_suffix_drop_const_is_supported(
    func,
    use_def,
    @ir.hot_child_get(func, loop_id, 0),
  )
}

///|
fn flatten_try_table_dead_suffix_root_nodes(
  func : @ir.HotFunc,
  use_def : @ir.HotNodeUseCounts,
  root_id : Int,
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Block =>
      if flatten_try_table_dead_suffix_structured_block_is_supported(
          func,
          use_def,
          root_id,
          state~,
        ) {
        Some([root_id])
      } else {
        None
      }
    @ir.HotOp::If =>
      if flatten_try_table_dead_suffix_structured_if_is_supported(
          func,
          use_def,
          root_id,
          state~,
        ) {
        Some([root_id])
      } else {
        None
      }
    @ir.HotOp::Loop =>
      if flatten_try_table_dead_suffix_structured_loop_is_supported(
          func,
          use_def,
          root_id,
          state~,
        ) {
        Some([root_id])
      } else {
        None
      }
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
  let (node_marks, node_mark) = match state {
    Some(state) => (state.node_marks, flatten_take_node_mark(state))
    None => (Array::make(@ir.hot_node_count(func), 0), 1)
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
      let mut all_structured_control_roots = true
      let mut all_supported_roots = true
      let mut saw_structured_control_root = false
      let mut saw_ordinary_root = false
      for suffix_idx = root_idx + 1
          suffix_idx < root_count
          suffix_idx = suffix_idx + 1 {
        let root_id = @ir.hot_region_get(func, region_ref, suffix_idx)
        let recognized_root = flatten_try_table_dead_suffix_root_nodes(
          func,
          use_def,
          root_id,
          state~,
        )
        recognized_suffix_roots.push(recognized_root)
        if recognized_root is None {
          all_supported_roots = false
        }
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
        let root_is_structured_control = match
          @ir.hot_node_get(func, root_id).op {
          @ir.HotOp::Block | @ir.HotOp::If | @ir.HotOp::Loop =>
            recognized_root is Some(_)
          _ => false
        }
        if root_is_structured_control {
          saw_structured_control_root = true
        } else {
          all_structured_control_roots = false
          saw_ordinary_root = true
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
      let mixed_supported_forest = all_supported_roots &&
        saw_structured_control_root &&
        saw_ordinary_root
      if !all_unreachable &&
        !all_direct_drop_consts &&
        !exact_drop_const_then_unreachable &&
        !exact_unreachable_then_drop_const &&
        !exact_add_drop_then_unreachable &&
        !exact_unreachable_then_add_drop &&
        !all_direct_sequence_roots &&
        !all_structured_control_roots &&
        !mixed_supported_forest {
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
        flatten_try_table_dead_suffix_root_nodes(func, use_def, root_id, state~)
      }
      let root_nodes = match recognized_root {
        Some(root_nodes) => root_nodes
        None => return None
      }
      for node_id in root_nodes {
        if node_id < 0 ||
          node_id >= node_marks.length() ||
          node_marks[node_id] == node_mark {
          return None
        }
        node_marks[node_id] = node_mark
        nodes.push(node_id)
      }
    }
    match state {
      Some(state) =>
        flatten_dead_suffix_entry_set(
          state.dead_suffix_entries,
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
      flatten_terminal_table_entry_set(
        state.terminal_table_entries,
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
  let targets = match flatten_br_table_targets(func, node.imm0, state~) {
    Some(targets) => targets
    None => return false
  }
  if !flatten_br_table_targets_contains(targets, label_id) ||
    (!allow_mixed_targets && targets.count != 1) {
    return false
  }
  let try_id = @ir.hot_label_owner(func, label_id)
  match @ir.hot_node_get(func, try_id).op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  let target_controls : Array[Int] = []
  for target_slot = 0
      target_slot < targets.count
      target_slot = target_slot + 1 {
    let target = flatten_br_table_target_at(targets, target_slot)
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
    flatten_direct_enclosing_target_controls(
      func,
      try_id,
      target_controls,
      state~,
    ) {
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
        flatten_type_results(func, tuple.ty, state~) != result_types ||
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
      let value_types = flatten_type_results(
        func,
        @ir.hot_node_get(func, value_id).ty,
        state~,
      )
      if value_types.length() != 1 ||
        value_types[0] != result_types[slot] ||
        !flatten_value_type_is_defaultable(result_types[slot]) ||
        !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
        return None
      }
    }
  } else {
    for slot = 0; slot < payload_count; slot = slot + 1 {
      let payload_id = @ir.hot_child_get(func, branch_id, slot)
      // Each distinct payload has exactly one branch edge and one false-flow
      // consumer. Repeating it in another lane would raise the exact count.
      if @ir.hot_node_use_count(use_counts, payload_id) != 2 {
        return None
      }
      let payload_types = flatten_type_results(
        func,
        @ir.hot_node_get(func, payload_id).ty,
        state~,
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
      let mut rich_left_id = -1
      let mut rich_binary_id = -1
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
        let allow_rich_left = offset == payload_count - 1
        if tuple_id >= 0 {
          if !flatten_multivalue_tuple_br_if_consumer_matches_lane(
              func,
              use_counts,
              consumer_id,
              tuple_id,
              result_types[payload_count - 1 - offset],
              allow_rich_left~,
            ) {
            return None
          }
          if allow_rich_left {
            let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
            match @ir.hot_node_get(func, consumed_id).op {
              @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 &&
                @ir.hot_child_get(func, consumed_id, 1) == tuple_id => {
                let left_id = @ir.hot_child_get(func, consumed_id, 0)
                if !flatten_node_is_simple_operand(func, left_id) {
                  let payloads : Array[Int] = []
                  for slot = 0; slot < payload_count; slot = slot + 1 {
                    payloads.push(@ir.hot_child_get(func, tuple_id, slot))
                  }
                  if !flatten_rich_left_payload_vector_is_supported(
                      func,
                      payloads,
                      allow_multiple=true,
                    ) {
                    return None
                  }
                  rich_left_id = left_id
                  rich_binary_id = consumed_id
                }
              }
              _ => ()
            }
          }
        } else {
          if !flatten_multivalue_loop_br_if_consumer_matches_payload(
              func,
              use_counts,
              consumer_id,
              expected_payload,
              allow_rich_left~,
            ) {
            return None
          }
          if allow_rich_left {
            let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
            match @ir.hot_node_get(func, consumed_id).op {
              @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 &&
                @ir.hot_child_get(func, consumed_id, 1) == expected_payload => {
                let left_id = @ir.hot_child_get(func, consumed_id, 0)
                if !flatten_node_is_simple_operand(func, left_id) {
                  let payloads : Array[Int] = []
                  for slot = 0; slot < payload_count; slot = slot + 1 {
                    payloads.push(@ir.hot_child_get(func, branch_id, slot))
                  }
                  if !flatten_rich_left_payload_vector_is_supported(
                      func,
                      payloads,
                      allow_multiple=true,
                    ) {
                    return None
                  }
                  rich_left_id = left_id
                  rich_binary_id = consumed_id
                }
              }
              _ => ()
            }
          }
        }
      }
      return Some([tuple_id, arm, root_idx, rich_left_id, rich_binary_id])
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
          let payload_types = flatten_type_results(
            func,
            @ir.hot_node_get(func, payload_id).ty,
            state~,
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
          let payload_types = flatten_type_results(
            func,
            @ir.hot_node_get(func, payload_id).ty,
            state~,
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
  let result_types = flatten_type_results(func, try_node.ty, state~)
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
        func,
        region_ref,
        result_types,
        state~,
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
  let result_types = flatten_type_results(
    func,
    @ir.hot_node_get(func, try_id).ty,
    state=Some(state),
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
        state=Some(state),
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
  let result_types = flatten_type_results(func, loop_node.ty, state=Some(state))
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
  if !flatten_multivalue_region_tail_matches_types(
      func,
      body_ref,
      result_types,
      state=Some(state),
    ) &&
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
  let result_types = flatten_type_results(func, block.ty, state=Some(state))
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
  if body_count >= 2 &&
    flatten_terminal_payload_contains(state.terminal_payloads, tail_id) {
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
          state~,
        )
        is Some(_) {
        return true
      }
    }
    _ => ()
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, node_id, slot)
    let payload_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, payload_id).ty,
      state~,
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
fn flatten_false_flow_binary_right_operand_is_supported(
  func : @ir.HotFunc,
  use_counts : @ir.HotNodeUseCounts,
  operand_id : Int,
) -> Bool {
  flatten_node_is_simple_operand(func, operand_id) ||
  (
    @ir.hot_node_use_count(use_counts, operand_id) == 1 &&
    flatten_scalar_branch_payload_has_supported_origin(func, operand_id)
  )
}

///|
fn flatten_rich_left_payload_vector_is_supported(
  func : @ir.HotFunc,
  payloads : Array[Int],
  allow_multiple? : Bool = false,
) -> Bool {
  let mut rich_payload_count = 0
  for payload_id in payloads {
    if flatten_node_is_simple_operand(func, payload_id) {
      continue
    }
    if !flatten_scalar_branch_payload_has_supported_origin(func, payload_id) {
      return false
    }
    rich_payload_count = rich_payload_count + 1
    if rich_payload_count > 1 && !allow_multiple {
      return false
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
  allow_rich_left? : Bool = false,
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
    @ir.hot_child_count(func, consumed_id) == 0 {
    return false
  }
  match consumed.op {
    @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 => {
      let payload_is_left = @ir.hot_child_get(func, consumed_id, 0) ==
        payload_id &&
        flatten_false_flow_binary_right_operand_is_supported(
          func,
          use_counts,
          @ir.hot_child_get(func, consumed_id, 1),
        )
      let left_id = @ir.hot_child_get(func, consumed_id, 0)
      let payload_is_right = @ir.hot_child_get(func, consumed_id, 1) ==
        payload_id &&
        (
          flatten_node_is_simple_operand(func, left_id) ||
          (
            allow_rich_left &&
            @ir.hot_node_use_count(use_counts, left_id) == 1 &&
            flatten_scalar_branch_payload_has_supported_origin(func, left_id)
          )
        )
      if !payload_is_left && !payload_is_right {
        return false
      }
      match
        (
          flatten_single_result_type(
            func,
            @ir.hot_node_get(func, payload_id).ty,
          ),
          flatten_single_result_type(func, consumed.ty),
        ) {
        (Some(payload_type), Some(consumed_type)) =>
          consumed_type == payload_type
        _ => false
      }
    }
    @ir.HotOp::Unary | @ir.HotOp::Convert =>
      @ir.hot_child_count(func, consumed_id) == 1 &&
      @ir.hot_child_get(func, consumed_id, 0) == payload_id &&
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
  allow_rich_left? : Bool = false,
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
    @ir.hot_child_count(func, consumed_id) == 0 {
    return false
  }
  match consumed.op {
    @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 => {
      let tuple_is_left = @ir.hot_child_get(func, consumed_id, 0) == tuple_id &&
        flatten_false_flow_binary_right_operand_is_supported(
          func,
          use_counts,
          @ir.hot_child_get(func, consumed_id, 1),
        )
      let left_id = @ir.hot_child_get(func, consumed_id, 0)
      let tuple_is_right = @ir.hot_child_get(func, consumed_id, 1) == tuple_id &&
        (
          flatten_node_is_simple_operand(func, left_id) ||
          (
            allow_rich_left &&
            @ir.hot_node_use_count(use_counts, left_id) == 1 &&
            flatten_scalar_branch_payload_has_supported_origin(func, left_id)
          )
        )
      (tuple_is_left || tuple_is_right) &&
      @ir.hot_node_exact_instr(func, consumed_id) is Some(_) &&
      flatten_single_result_type(func, consumed.ty) == Some(lane_type)
    }
    @ir.HotOp::Unary | @ir.HotOp::Convert =>
      @ir.hot_child_count(func, consumed_id) == 1 &&
      @ir.hot_child_get(func, consumed_id, 0) == tuple_id &&
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
  if @ir.hot_child_count(func, consumed_id) == 0 {
    return false
  }
  let payload_slot = if @ir.hot_child_get(func, consumed_id, 0) == payload_id {
    0
  } else if @ir.hot_child_count(func, consumed_id) == 2 &&
    @ir.hot_child_get(func, consumed_id, 1) == payload_id {
    1
  } else {
    return false
  }
  @ir.hot_child_set(
    func,
    consumed_id,
    payload_slot,
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
  state? : FlattenRewriteState? = None,
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
  if flatten_type_results(func, tuple.ty, state~) != param_types ||
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
  let mut rich_left_id = -1
  let mut rich_binary_id = -1
  for offset = 0; offset < payload_count; offset = offset + 1 {
    let consumer_id = @ir.hot_region_get(
      func,
      body_ref,
      branch_root + 1 + offset,
    )
    let allow_rich_left = offset == payload_count - 1
    if !flatten_multivalue_tuple_br_if_consumer_matches_lane(
        func,
        counts,
        consumer_id,
        tuple_id,
        param_types[payload_count - 1 - offset],
        allow_rich_left~,
      ) {
      return None
    }
    if allow_rich_left {
      let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
      match @ir.hot_node_get(func, consumed_id).op {
        @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 &&
          @ir.hot_child_get(func, consumed_id, 1) == tuple_id => {
          let left_id = @ir.hot_child_get(func, consumed_id, 0)
          if !flatten_node_is_simple_operand(func, left_id) {
            let payloads : Array[Int] = []
            for slot = 0; slot < payload_count; slot = slot + 1 {
              payloads.push(@ir.hot_child_get(func, tuple_id, slot))
            }
            if !flatten_rich_left_payload_vector_is_supported(
                func,
                payloads,
                allow_multiple=true,
              ) {
              return None
            }
            rich_left_id = left_id
            rich_binary_id = consumed_id
          }
        }
        _ => ()
      }
    }
  }
  if @ir.hot_node_use_count(counts, tuple_id) != payload_count * 2 {
    return None
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = @ir.hot_child_get(func, tuple_id, slot)
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
    )
    if value_types.length() != 1 ||
      value_types[0] != param_types[slot] ||
      !flatten_value_type_is_defaultable(param_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, value_id) {
      return None
    }
  }
  Some([tuple_id, branch_root, rich_left_id, rich_binary_id])
}

///|
fn flatten_multivalue_loop_br_if_flow(
  func : @ir.HotFunc,
  loop_id : Int,
  branch_id : Int,
  param_types : Array[@lib.ValType],
  use_counts? : @ir.HotNodeUseCounts? = None,
  state? : FlattenRewriteState? = None,
) -> Array[Int]? {
  let payload_count = param_types.length()
  let label_id = @ir.hot_control_node_label(func, loop_id)
  let branch = @ir.hot_node_get(func, branch_id)
  match branch.op {
    @ir.HotOp::BrIf if branch.imm0 == label_id &&
      payload_count > 1 &&
      @ir.hot_child_count(func, branch_id) == payload_count + 1 => ()
    _ => return None
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
  let payloads : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, branch_id, slot)
    let payload_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, payload_id).ty,
      state~,
    )
    // One branch edge plus one exact consumer is the complete ownership
    // population; a repeated lane would make the count exceed two.
    if @ir.hot_node_use_count(counts, payload_id) != 2 ||
      payload_types.length() != 1 ||
      payload_types[0] != param_types[slot] ||
      !flatten_value_type_is_defaultable(param_types[slot]) ||
      !flatten_scalar_branch_payload_has_supported_origin(func, payload_id) {
      return None
    }
    payloads.push(payload_id)
  }
  let mut rich_left_id = -1
  let mut rich_binary_id = -1
  for offset = 0; offset < payload_count; offset = offset + 1 {
    let consumer_id = @ir.hot_region_get(
      func,
      body_ref,
      branch_root + 1 + offset,
    )
    let payload_id = payloads[payload_count - 1 - offset]
    let allow_rich_left = offset == payload_count - 1
    if !flatten_multivalue_loop_br_if_consumer_matches_payload(
        func,
        counts,
        consumer_id,
        payload_id,
        allow_rich_left~,
      ) {
      return None
    }
    if allow_rich_left {
      let consumed_id = @ir.hot_child_get(func, consumer_id, 0)
      match @ir.hot_node_get(func, consumed_id).op {
        @ir.HotOp::Binary if @ir.hot_child_count(func, consumed_id) == 2 &&
          @ir.hot_child_get(func, consumed_id, 1) == payload_id => {
          let left_id = @ir.hot_child_get(func, consumed_id, 0)
          if !flatten_node_is_simple_operand(func, left_id) {
            if !flatten_rich_left_payload_vector_is_supported(
                func,
                payloads,
                allow_multiple=true,
              ) {
              return None
            }
            rich_left_id = left_id
            rich_binary_id = consumed_id
          }
        }
        _ => ()
      }
    }
  }
  Some([branch_root, rich_left_id, rich_binary_id])
}

///|
fn flatten_multivalue_loop_br_if_flows_are_exact(
  func : @ir.HotFunc,
  loop_id : Int,
  label_id : Int,
  payload_count : Int,
  state? : FlattenRewriteState? = None,
) -> Bool {
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
        state~,
      )
      is Some(_) {
      continue
    }
    if flatten_multivalue_loop_br_if_flow(
        func,
        loop_id,
        branch_id,
        param_types,
        use_counts=Some(use_counts),
        state~,
      )
      is None {
      return false
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
  if flatten_multivalue_region_tail_matches_types(
      func,
      body_ref,
      result_types,
      state~,
    ) ||
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
  if flatten_type_results(func, @ir.hot_node_get(func, nested_id).ty, state~) !=
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
        func,
        nested_label,
        result_types,
        admitted_table,
        state~,
      )
    @ir.HotOp::Try =>
      flatten_multivalue_legacy_try_is_supported(func, nested_id, state~)
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
  if flatten_type_results(func, tuple.ty, state~) != param_types ||
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
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
  match state {
    Some(state) => {
      let entry_index = flatten_inputful_loop_support_entry_index(
        state.inputful_loop_support_entries,
        loop_id,
      )
      if entry_index >= 0 {
        return state.inputful_loop_support_entries[entry_index].supported
      }
      if state.rewrites_started {
        return false
      }
      let supported = flatten_inputful_loop_is_supported_uncached(
        func,
        loop_id,
        state=Some(state),
      )
      flatten_inputful_loop_support_entry_set(
        state.inputful_loop_support_entries,
        loop_id,
        supported,
      )
      supported
    }
    None => flatten_inputful_loop_is_supported_uncached(func, loop_id)
  }
}

///|
fn flatten_inputful_loop_is_supported_uncached(
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
  let result_types = flatten_type_results(func, loop_node.ty, state~)
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
      let entry_types = flatten_type_results(
        func,
        @ir.hot_node_get(func, entry_id).ty,
        state~,
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
  visited_marks : Array[Int],
  visited_mark : Int,
) -> Unit {
  if node_id < 0 ||
    node_id >= visited_marks.length() ||
    !@ir.hot_node_is_live(func, node_id) ||
    visited_marks[node_id] == visited_mark {
    return
  }
  visited_marks[node_id] = visited_mark
  let child_count = @ir.hot_child_count(func, node_id)
  for slot = 0; slot < child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id == entry_id {
      @ir.hot_child_set(func, node_id, slot, replacement_id)
    } else {
      flatten_replace_loop_entry_in_node(
        func, child_id, entry_id, replacement_id, visited_marks, visited_mark,
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
    let entry_type = flatten_type_results(
        func,
        @ir.hot_node_get(func, entry_id).ty,
        state=Some(state),
      )[0]
    let local_id = @ir.hot_append_body_local(func, entry_type)
    state.label_temps[label_id].push(local_id)
    preludes.push(@ir.hot_build_local_set(func, local_id, entry_id))
    let replacement_id = @ir.hot_build_local_get(func, local_id)
    let visited_mark = flatten_take_node_mark(state)
    for root_idx = 0
        root_idx < @ir.hot_region_root_count(func, body_ref)
        root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, body_ref, root_idx)
      if root_id == entry_id {
        ignore(@ir.hot_region_set(func, body_ref, root_idx, replacement_id))
      } else {
        flatten_replace_loop_entry_in_node(
          func,
          root_id,
          entry_id,
          replacement_id,
          state.node_marks,
          visited_mark,
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
  state : FlattenRewriteState,
  loop_id : Int,
) -> Int? {
  let loop_node = @ir.hot_node_get(func, loop_id)
  match loop_node.op {
    @ir.HotOp::Loop => ()
    _ => return None
  }
  let result_types = flatten_type_results(func, loop_node.ty, state=Some(state))
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
      flatten_scalar_try_entry_set(state.scalar_try_entries, try_id, supported)
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
  let result_types = flatten_type_results(func, try_node.ty, state~)
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
    let tail_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, tail_id).ty,
      state~,
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
  let result_type = flatten_type_results(
      func,
      @ir.hot_node_get(func, try_id).ty,
      state=Some(state),
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
fn flatten_node_is_rethrow(func : @ir.HotFunc, node_id : Int) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Rethrow => true
    _ => false
  }
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
  let result_types = flatten_type_results(func, if_node.ty, state=Some(state))
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
    !flatten_terminal_branch_targets_label(func, then_tail, label_id, false) &&
    !flatten_node_is_rethrow(func, then_tail) {
    return None
  }
  if !else_has_fallthrough_value &&
    !flatten_terminal_branch_targets_label(func, else_tail, label_id, false) &&
    !flatten_node_is_rethrow(func, else_tail) {
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
    @ir.HotOp::Loop => flatten_try_route_scalar_loop(ctx, func, state, node_id)
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
      match
        (
          flatten_single_result_type(func, @ir.hot_node_get(func, value_id).ty),
          flatten_single_result_type(func, consumed.ty),
        ) {
        (Some(value_type), Some(consumed_type)) => consumed_type == value_type
        _ => false
      }
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
            flatten_scalar_br_if_flow_entry_set(
              state.scalar_br_if_flow_entries,
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
        let value_types = flatten_type_results(
          func,
          @ir.hot_node_get(func, @ir.hot_child_get(func, branch_id, 0)).ty,
          state~,
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
        let value_types = flatten_type_results(
          func,
          @ir.hot_node_get(func, value_id).ty,
          state~,
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
        let value_types = flatten_type_results(
          func,
          @ir.hot_node_get(func, value_id).ty,
          state~,
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
fn flatten_collect_distinct_branch_payloads(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
  seen : @bitset.BitSet,
) -> Array[Int]? {
  if payload_count <= 0 ||
    branch_id < 0 ||
    !@ir.hot_node_is_live(func, branch_id) ||
    @ir.hot_child_count(func, branch_id) < payload_count {
    return None
  }
  let payloads : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, branch_id, slot)
    if payload_id < 0 || payload_id >= seen.length() || seen[payload_id] {
      return None
    }
    seen[payload_id] = true
    payloads.push(payload_id)
  }
  Some(payloads)
}

///|
fn flatten_collect_distinct_branch_payload_slots(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
  payload_slots : Array[Int],
) -> Array[Int]? {
  if payload_count <= 0 ||
    branch_id < 0 ||
    !@ir.hot_node_is_live(func, branch_id) ||
    @ir.hot_child_count(func, branch_id) < payload_count {
    return None
  }
  let payloads : Array[Int] = []
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let payload_id = @ir.hot_child_get(func, branch_id, slot)
    if payload_id < 0 ||
      payload_id >= payload_slots.length() ||
      payload_slots[payload_id] >= 0 {
      return None
    }
    payload_slots[payload_id] = slot
    payloads.push(payload_id)
  }
  Some(payloads)
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
  let payloads = match
    flatten_collect_distinct_branch_payloads(
      func,
      branch_id,
      payload_count,
      @bitset.BitSet::new(@ir.hot_node_count(func)),
    ) {
    Some(payloads) => payloads
    None => return false
  }
  for slot = 0; slot < payload_count; slot = slot + 1 {
    if @ir.hot_child_get(func, flow[0], flow[1] + slot) != payloads[slot] {
      return false
    }
  }
  true
}

///|
fn flatten_locate_reachable_multivalue_br_if_flow_span(
  func : @ir.HotFunc,
  branch_id : Int,
  payload_count : Int,
) -> Array[Int]? {
  let payload_slots = Array::make(@ir.hot_node_count(func), -1)
  if flatten_collect_distinct_branch_payload_slots(
      func, branch_id, payload_count, payload_slots,
    )
    is None {
    return None
  }
  let seen = @bitset.BitSet::new(@ir.hot_node_count(func))
  let worklist : Array[Int] = []
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root_id = @ir.hot_root_get(func, root_idx)
    if root_id >= 0 &&
      root_id < payload_slots.length() &&
      payload_slots[root_id] >= 0 {
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
      let payload_slot = if child_id >= 0 && child_id < payload_slots.length() {
        payload_slots[child_id]
      } else {
        -1
      }
      if payload_slot >= 0 {
        counts[payload_slot] = counts[payload_slot] + 1
        if node_id != branch_id || child_slot != payload_slot {
          if parents[payload_slot] >= 0 {
            return None
          }
          parents[payload_slot] = node_id
          slots[payload_slot] = child_slot
        }
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
        flatten_br_if_flow_entry_set(
          state.multivalue_br_if_flow_entries,
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
fn flatten_record_distinct_flow_slot(
  flow_slots : Array[Int],
  seen : Array[Bool],
  slot : Int,
) -> Bool {
  if slot < 0 || slot >= seen.length() || seen[slot] {
    return false
  }
  seen[slot] = true
  flow_slots.push(slot)
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
  let flow_slot_seen : Array[Bool] = []
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
            flow_slot_seen.append(Array::make(child_count, false))
          } else if flow_parent != node_id {
            return None
          }
          if !flatten_record_distinct_flow_slot(
              flow_slots, flow_slot_seen, child_slot,
            ) {
            return None
          }
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
  if flatten_type_results(func, tuple.ty, state~) != target_types ||
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
        flatten_br_if_flow_entry_set(
          state.tuple_br_if_flow_entries,
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
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
  if flatten_type_results(func, tuple.ty, state~) != target_types ||
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
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
  let targets = match
    flatten_br_table_targets(
      func,
      @ir.hot_node_get(func, table_id).imm0,
      state~,
    ) {
    Some(targets) => targets
    None => return None
  }
  if targets.count == 0 {
    return None
  }
  let first_target = flatten_br_table_target_at(targets, 0)
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
      flatten_type_results(
        func,
        @ir.hot_label_result_type(func, first_target),
        state~,
      )
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
    let value_types = flatten_type_results(
      func,
      @ir.hot_node_get(func, value_id).ty,
      state~,
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
      let nested_types = flatten_type_results(
        func,
        @ir.hot_node_get(func, nested_id).ty,
        state~,
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
        func,
        region_ref,
        target_types,
        state~,
      ) &&
      !flatten_multivalue_region_tail_repeats_tuple(
        func,
        region_ref,
        target_types,
        state~,
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
            let payload_types = flatten_type_results(
              func,
              @ir.hot_node_get(func, payload_id).ty,
              state~,
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
            let payload_types = flatten_type_results(
              func,
              @ir.hot_node_get(func, payload_id).ty,
              state~,
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
            let payload_types = flatten_type_results(
              func,
              @ir.hot_node_get(func, payload_id).ty,
              state~,
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
  let value_types = flatten_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
    state=Some(state),
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
          let payload_types = flatten_type_results(
            func,
            @ir.hot_node_get(func, payload_id).ty,
            state=Some(state),
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
  let target_types = flatten_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
    state=Some(state),
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
          state=Some(state),
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
  let target_types = flatten_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
    state=Some(state),
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
      if flow[3] >= 0 {
        let rich_left_type = match
          flatten_single_result_type(func, @ir.hot_node_get(func, flow[3]).ty) {
          Some(rich_left_type) => rich_left_type
          None => return false
        }
        let rich_left_local = @ir.hot_append_body_local(func, rich_left_type)
        preludes.insert(
          0,
          @ir.hot_build_local_set(func, rich_left_local, flow[3]),
        )
        @ir.hot_child_set(
          func,
          flow[4],
          0,
          @ir.hot_build_local_get(func, rich_left_local),
        )
      }
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
  let value_types = flatten_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
    state=Some(state),
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
        state=Some(state),
      )
      match tuple_flow {
        Some(flow) => {
          if flow[2] >= 0 {
            let rich_left_type = match
              flatten_single_result_type(
                func,
                @ir.hot_node_get(func, flow[2]).ty,
              ) {
              Some(rich_left_type) => rich_left_type
              None => return false
            }
            let rich_left_local = @ir.hot_append_body_local(
              func, rich_left_type,
            )
            preludes.insert(
              0,
              @ir.hot_build_local_set(func, rich_left_local, flow[2]),
            )
            @ir.hot_child_set(
              func,
              flow[3],
              0,
              @ir.hot_build_local_get(func, rich_left_local),
            )
          }
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
      if payload_count > 1 {
        let flow = match
          flatten_multivalue_loop_br_if_flow(
            func,
            @ir.hot_label_owner(func, label_id),
            node_id,
            param_types,
            use_counts=Some(state.use_def),
            state=Some(state),
          ) {
          Some(flow) => flow
          None => return false
        }
        if flow[1] >= 0 {
          let rich_left_type = match
            flatten_single_result_type(func, @ir.hot_node_get(func, flow[1]).ty) {
            Some(rich_left_type) => rich_left_type
            None => return false
          }
          let rich_left_local = @ir.hot_append_body_local(func, rich_left_type)
          preludes.push(@ir.hot_build_local_set(func, rich_left_local, flow[1]))
          @ir.hot_child_set(
            func,
            flow[2],
            0,
            @ir.hot_build_local_get(func, rich_left_local),
          )
        }
      }
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let payload_id = @ir.hot_child_get(func, node_id, slot)
        let payload_types = flatten_type_results(
          func,
          @ir.hot_node_get(func, payload_id).ty,
          state=Some(state),
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
  let target_types = flatten_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
    state=Some(state),
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
fn flatten_record_unique_br_table_target(
  targets : Array[Int],
  seen : @bitset.BitSet,
  target : Int,
) -> Bool {
  if target < 0 || target >= seen.length() || seen[target] {
    return false
  }
  seen[target] = true
  targets.push(target)
  true
}

///|
fn flatten_unique_br_table_targets(
  func : @ir.HotFunc,
  table_id : Int,
) -> Array[Int] {
  let unique : Array[Int] = []
  let seen = @bitset.BitSet::new(func.labels.length())
  for target in @ir.hot_branch_table_targets(func, table_id) {
    ignore(flatten_record_unique_br_table_target(unique, seen, target))
  }
  ignore(
    flatten_record_unique_br_table_target(
      unique,
      seen,
      @ir.hot_branch_table_default_target(func, table_id),
    ),
  )
  unique
}

///|
fn flatten_br_table_targets(
  func : @ir.HotFunc,
  table_id : Int,
  state? : FlattenRewriteState? = None,
) -> FlattenBrTableTargets? {
  match state {
    Some(state) => {
      let entry_index = flatten_br_table_targets_entry_index(
        state.br_table_target_entries,
        table_id,
      )
      if entry_index < 0 {
        return None
      }
      let entry = state.br_table_target_entries[entry_index]
      Some(
        FlattenBrTableTargets::new(
          state.br_table_targets,
          entry.start,
          entry.count,
        ),
      )
    }
    None => {
      let targets = flatten_unique_br_table_targets(func, table_id)
      Some(FlattenBrTableTargets::new(targets, 0, targets.length()))
    }
  }
}

///|
fn flatten_br_table_targets_contains(
  targets : FlattenBrTableTargets,
  label_id : Int,
) -> Bool {
  for offset = 0; offset < targets.count; offset = offset + 1 {
    if targets.targets[targets.start + offset] == label_id {
      return true
    }
  }
  false
}

///|
fn flatten_br_table_target_at(
  targets : FlattenBrTableTargets,
  offset : Int,
) -> Int {
  targets.targets[targets.start + offset]
}

///|
fn flatten_prepare_br_table_target_locals(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  targets : FlattenBrTableTargets,
  payload_types : Array[@lib.ValType],
) -> Bool {
  if !state.rewrites_started || payload_types.is_empty() {
    return false
  }
  for target_slot = 0
      target_slot < targets.count
      target_slot = target_slot + 1 {
    let target = flatten_br_table_target_at(targets, target_slot)
    if target < 0 || target >= state.label_temps.length() {
      return false
    }
    let locals = state.label_temps[target]
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::LoopLabel =>
        if !flatten_label_temps_match_types(func, state, target, payload_types) {
          return false
        }
      @ir.HotLabelKind::BlockLabel
      | @ir.HotLabelKind::IfLabel
      | @ir.HotLabelKind::TryLabel =>
        if !locals.is_empty() &&
          !flatten_label_temps_match_types(func, state, target, payload_types) {
          return false
        }
      _ => return false
    }
  }
  for target_slot = 0
      target_slot < targets.count
      target_slot = target_slot + 1 {
    let target = flatten_br_table_target_at(targets, target_slot)
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::LoopLabel => ()
      _ =>
        if flatten_ensure_label_temps(func, state, target, payload_types)
          is None {
          return false
        }
    }
  }
  true
}

///|
fn flatten_br_table_staging_locals(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  targets : FlattenBrTableTargets,
  payload_types : Array[@lib.ValType],
) -> Array[Int] {
  if targets.count == 1 {
    return state.label_temps[flatten_br_table_target_at(targets, 0)]
  }
  let staging : Array[Int] = []
  for payload_type in payload_types {
    staging.push(@ir.hot_append_body_local(func, payload_type))
  }
  staging
}

///|
fn flatten_tuple_mixed_try_table_is_supported(
  func : @ir.HotFunc,
  table_id : Int,
  payload_types : Array[@lib.ValType],
  targets : FlattenBrTableTargets,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let tuple_values = flatten_multivalue_tuple_branch_payload_values(
    func,
    table_id,
    payload_types.length(),
    payload_types,
    state~,
  )
  if tuple_values is None || targets.count <= 1 {
    return true
  }
  let mut try_label = -1
  let mut enclosing_control_count = 0
  for target_slot = 0
      target_slot < targets.count
      target_slot = target_slot + 1 {
    let target = flatten_br_table_target_at(targets, target_slot)
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
  enclosing_control_count == targets.count - 1 &&
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
  let targets = match
    flatten_br_table_targets(func, branch.imm0, state=Some(state)) {
    Some(targets) => targets
    None => return false
  }
  if targets.count == 0 {
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
  for target_slot = 0
      target_slot < targets.count
      target_slot = target_slot + 1 {
    let target = flatten_br_table_target_at(targets, target_slot)
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
        let target_types = flatten_type_results(
          func,
          @ir.hot_label_result_type(func, target),
          state=Some(state),
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
        let target_types = flatten_type_results(
          func,
          @ir.hot_label_result_type(func, target),
          state=Some(state),
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
  if !flatten_prepare_br_table_target_locals(
      func, state, targets, payload_types,
    ) {
    return false
  }
  let value_locals = flatten_br_table_staging_locals(
    func, state, targets, payload_types,
  )
  for slot = 0; slot < payload_count; slot = slot + 1 {
    let value_id = match tuple_values {
      Some(values) => values[slot]
      None => @ir.hot_child_get(func, node_id, slot)
    }
    preludes.push(@ir.hot_build_local_set(func, value_locals[slot], value_id))
    ignore(flatten_terminal_payload_record(state.terminal_payloads, value_id))
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
        let detached_roots = @ir.hot_region_truncate_suffix(
          func,
          owner_region,
          root_idx + 1,
        )
        pass_mark_mutated(ctx, func)
        if !@ir.hot_delete_detached_forest(func, detached_roots) {
          abort("flatten suffix forest deletion violated admission proof")
        }
        break
      }
    }
    _ => ()
  }
  for target_slot = 0
      target_slot < targets.count
      target_slot = target_slot + 1 {
    let target_locals = state.label_temps[flatten_br_table_target_at(
        targets, target_slot,
      )]
    for slot = 0; slot < payload_count; slot = slot + 1 {
      if target_locals[slot] != value_locals[slot] {
        preludes.push(
          @ir.hot_build_local_set(
            func,
            target_locals[slot],
            @ir.hot_build_local_get(func, value_locals[slot]),
          ),
        )
      }
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
  let already_sequenced = flatten_sequenced_root_contains(
    state.sequenced_root_holders,
    state.sequenced_root_nodes,
    owner_region.holder,
    child_id,
  )
  if !already_sequenced {
    preludes.push(child_id)
  }
  @ir.hot_child_set(func, parent_id, slot, @ir.hot_build_unreachable(func))
  true
}

///|
fn flatten_spill_scalar_operand(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
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
  let result_types = flatten_type_results(func, child.ty, state=Some(state))
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
  let depth = state.prelude_depth
  state.prelude_depth = state.prelude_depth + 1
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let preludes = flatten_prelude_buffer(state, depth)
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
      ignore(
        flatten_sequenced_root_record(
          state.sequenced_root_holders,
          state.sequenced_root_nodes,
          region_ref.holder,
          node_id,
        ),
      )
    }
    if flatten_terminal_payload_contains(state.terminal_payloads, node_id) {
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
  state.prelude_depth = state.prelude_depth - 1
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
          func, state, parent_id, slot, child_id, preludes,
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
  state : FlattenRewriteState,
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
  let result_types = flatten_type_results(func, tail.ty, state=Some(state))
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
  match flatten_single_result_type(func, value.ty) {
    Some(value_type) => flatten_value_type_is_defaultable(value_type)
    None => false
  }
}

///|
fn flatten_has_deferred_inputful_loop(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
) -> Bool {
  for node_id in state.loop_nodes {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
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
  for node_id in state.try_nodes {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let result_arity = @ir.hot_node_result_arity(func, node_id)
    if result_arity == 1 &&
      !flatten_scalar_legacy_try_is_supported(func, node_id, state=Some(state)) {
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
  false
}

///|
fn flatten_has_deferred_rich_branch_payload(
  func : @ir.HotFunc,
  state? : FlattenRewriteState? = None,
) -> Bool {
  let branch_nodes = match state {
    Some(state) => state.branch_payload_nodes
    None => flatten_build_pre_mutation_node_index(func).branch_payload_nodes
  }
  for node_id in branch_nodes {
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
            let target_types = flatten_type_results(
              func,
              @ir.hot_label_result_type(func, label_id),
              state~,
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
            flatten_type_results(
              func,
              @ir.hot_label_result_type(func, label_id),
              state~,
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
                state~,
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
            let target_types = flatten_type_results(
              func,
              @ir.hot_label_result_type(func, label_id),
              state~,
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
        let targets = match flatten_br_table_targets(func, node.imm0, state~) {
          Some(targets) => targets
          None => return true
        }
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
          for target_slot = 0
              target_slot < targets.count
              target_slot = target_slot + 1 {
            let target = flatten_br_table_target_at(targets, target_slot)
            if target < 0 || target >= func.labels.length() {
              return true
            }
            match @ir.hot_label_kind(func, target) {
              @ir.HotLabelKind::LoopLabel =>
                if @ir.hot_label_branch_arity(func, target) != payload_count {
                  return true
                }
              @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::IfLabel => {
                let target_types = flatten_type_results(
                  func,
                  @ir.hot_label_result_type(func, target),
                  state~,
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
fn flatten_direct_rethrow_value_if_is_supported(
  func : @ir.HotFunc,
  if_id : Int,
  rethrow_id : Int,
  state : FlattenRewriteState,
) -> Bool {
  let result_types = flatten_type_results(
    func,
    @ir.hot_node_get(func, if_id).ty,
    state=Some(state),
  )
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  if then_count == 0 || else_count == 0 {
    return false
  }
  let then_tail = @ir.hot_region_get(func, then_ref, then_count - 1)
  let else_tail = @ir.hot_region_get(func, else_ref, else_count - 1)
  let other_tail = if then_tail == rethrow_id && else_tail != rethrow_id {
    else_tail
  } else if else_tail == rethrow_id && then_tail != rethrow_id {
    then_tail
  } else {
    return false
  }
  flatten_type_results(
    func,
    @ir.hot_node_get(func, other_tail).ty,
    state=Some(state),
  ) ==
  result_types &&
  flatten_node_is_simple_operand(func, other_tail)
}

///|
fn flatten_markerless_catch_owns_root(
  func : @ir.HotFunc,
  try_id : Int,
  root_id : Int,
) -> Bool {
  let catch_ref = match @ir.hot_region_catch_ref(func, try_id) {
    Some(catch_ref) => catch_ref
    None => return false
  }
  let mut owns_root = false
  for idx = 0; idx < @ir.hot_region_root_count(func, catch_ref); idx = idx + 1 {
    let candidate = @ir.hot_region_get(func, catch_ref, idx)
    match @ir.hot_node_get(func, candidate).op {
      @ir.HotOp::Catch | @ir.HotOp::CatchAll => return false
      _ => ()
    }
    if candidate == root_id {
      owns_root = true
    }
  }
  owns_root
}

///|
fn flatten_rethrow_catch_root_through_strict_ancestry(
  func : @ir.HotFunc,
  root_id : Int,
  state : FlattenRewriteState,
) -> Int {
  let mut current = root_id
  let mut parent = state.direct_parent[current]
  while parent >= 0 {
    match @ir.hot_node_get(func, parent).op {
      @ir.HotOp::Block => {
        if @ir.hot_node_result_arity(func, parent) != 0 {
          return -1
        }
        let label_id = @ir.hot_control_node_label(func, parent)
        if label_id < 0 || !state.label_branch_nodes[label_id].is_empty() {
          return -1
        }
        let body_ref = @ir.hot_region_body_ref(func, parent)
        if @ir.hot_region_root_count(func, body_ref) != 1 ||
          @ir.hot_region_get(func, body_ref, 0) != current {
          return -1
        }
        current = parent
        parent = state.direct_parent[current]
      }
      @ir.HotOp::If => {
        if @ir.hot_node_result_arity(func, parent) != 0 {
          return -1
        }
        let label_id = @ir.hot_control_node_label(func, parent)
        if label_id < 0 || !state.label_branch_nodes[label_id].is_empty() {
          return -1
        }
        let then_ref = @ir.hot_region_then_ref(func, parent)
        let mut owns_current = @ir.hot_region_root_count(func, then_ref) == 1 &&
          @ir.hot_region_get(func, then_ref, 0) == current
        match @ir.hot_region_else_ref(func, parent) {
          Some(else_ref) =>
            if @ir.hot_region_root_count(func, else_ref) == 1 &&
              @ir.hot_region_get(func, else_ref, 0) == current {
              if owns_current {
                return -1
              }
              owns_current = true
            }
          None => ()
        }
        if !owns_current {
          return -1
        }
        current = parent
        parent = state.direct_parent[current]
      }
      _ => break
    }
  }
  current
}

///|
fn flatten_direct_catch_all_rethrow_is_supported(
  func : @ir.HotFunc,
  rethrow_id : Int,
  state : FlattenRewriteState,
) -> Bool {
  let rethrow = @ir.hot_node_get(func, rethrow_id)
  match rethrow.op {
    @ir.HotOp::Rethrow => ()
    _ => return false
  }
  if rethrow.imm0 < 0 || !flatten_ensure_direct_parent(func, state) {
    return false
  }
  if rethrow.imm0 > 0 {
    let mut current = rethrow_id
    for depth = 0; depth <= rethrow.imm0; depth = depth + 1 {
      let catch_root = flatten_rethrow_catch_root_through_strict_ancestry(
        func, current, state,
      )
      if catch_root < 0 {
        return false
      }
      let owner = state.direct_parent[catch_root]
      if owner < 0 {
        return false
      }
      match @ir.hot_node_get(func, owner).op {
        @ir.HotOp::Try => ()
        _ => return false
      }
      if @ir.hot_node_result_arity(func, owner) != 0 ||
        !flatten_markerless_catch_owns_root(func, owner, catch_root) {
        return false
      }
      if depth == rethrow.imm0 {
        return true
      }
      current = owner
    }
    return false
  }
  let mut current = rethrow_id
  let mut parent = state.direct_parent[current]
  while parent >= 0 {
    match @ir.hot_node_get(func, parent).op {
      @ir.HotOp::Block => {
        current = parent
        parent = state.direct_parent[current]
      }
      @ir.HotOp::If => {
        let result_arity = @ir.hot_node_result_arity(func, parent)
        if result_arity != 0 &&
          (
            current != rethrow_id ||
            result_arity != 1 ||
            !flatten_direct_rethrow_value_if_is_supported(
              func, parent, rethrow_id, state,
            )
          ) {
          return false
        }
        let label_id = @ir.hot_control_node_label(func, parent)
        if label_id >= 0 && !state.label_branch_nodes[label_id].is_empty() {
          return false
        }
        current = parent
        parent = state.direct_parent[current]
      }
      _ => break
    }
  }
  if parent < 0 {
    return false
  }
  match @ir.hot_node_get(func, parent).op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  flatten_markerless_catch_owns_root(func, parent, current)
}

///|
fn flatten_direct_delegate_is_supported(
  func : @ir.HotFunc,
  delegate_id : Int,
  state : FlattenRewriteState,
) -> Bool {
  let delegate = @ir.hot_node_get(func, delegate_id)
  match delegate.op {
    @ir.HotOp::Delegate => ()
    _ => return false
  }
  if !flatten_ensure_direct_parent(func, state) {
    return false
  }
  let target_try = @ir.hot_label_owner(func, delegate.imm0)
  if target_try < 0 ||
    @ir.hot_control_node_label(func, target_try) != delegate.imm0 {
    return false
  }
  match @ir.hot_node_get(func, target_try).op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  let mut catch_root = delegate_id
  let mut catch_parent = state.direct_parent[catch_root]
  while catch_parent >= 0 {
    match @ir.hot_node_get(func, catch_parent).op {
      @ir.HotOp::Block => {
        if @ir.hot_node_result_arity(func, catch_parent) != 0 {
          return false
        }
        let block_label = @ir.hot_control_node_label(func, catch_parent)
        if block_label < 0 || !state.label_branch_nodes[block_label].is_empty() {
          return false
        }
        let block_body = @ir.hot_region_body_ref(func, catch_parent)
        if @ir.hot_region_root_count(func, block_body) != 1 ||
          @ir.hot_region_get(func, block_body, 0) != catch_root {
          return false
        }
        catch_root = catch_parent
        catch_parent = state.direct_parent[catch_root]
      }
      _ => break
    }
  }
  if catch_parent < 0 {
    return false
  }
  let delegated_try = catch_parent
  match @ir.hot_node_get(func, delegated_try).op {
    @ir.HotOp::Try => ()
    _ => return false
  }
  let catch_ref = match @ir.hot_region_catch_ref(func, delegated_try) {
    Some(catch_ref) => catch_ref
    None => return false
  }
  if @ir.hot_region_root_count(func, catch_ref) != 1 ||
    @ir.hot_region_get(func, catch_ref, 0) != catch_root ||
    @ir.hot_node_result_arity(func, delegated_try) != 0 {
    return false
  }
  let delegated_label = @ir.hot_control_node_label(func, delegated_try)
  if delegated_label < 0 ||
    !state.label_branch_nodes[delegated_label].is_empty() {
    return false
  }
  let mut current = delegated_try
  let mut parent = state.direct_parent[current]
  while parent >= 0 {
    match @ir.hot_node_get(func, parent).op {
      @ir.HotOp::Block => {
        if @ir.hot_node_result_arity(func, parent) != 0 {
          return false
        }
        let label_id = @ir.hot_control_node_label(func, parent)
        if label_id < 0 || !state.label_branch_nodes[label_id].is_empty() {
          return false
        }
        let body_ref = @ir.hot_region_body_ref(func, parent)
        if @ir.hot_region_root_count(func, body_ref) != 1 ||
          @ir.hot_region_get(func, body_ref, 0) != current {
          return false
        }
        current = parent
        parent = state.direct_parent[current]
      }
      @ir.HotOp::If => {
        if @ir.hot_node_result_arity(func, parent) != 0 {
          return false
        }
        let label_id = @ir.hot_control_node_label(func, parent)
        if label_id < 0 || !state.label_branch_nodes[label_id].is_empty() {
          return false
        }
        let then_ref = @ir.hot_region_then_ref(func, parent)
        let mut owns_current = @ir.hot_region_root_count(func, then_ref) == 1 &&
          @ir.hot_region_get(func, then_ref, 0) == current
        match @ir.hot_region_else_ref(func, parent) {
          Some(else_ref) =>
            if @ir.hot_region_root_count(func, else_ref) == 1 &&
              @ir.hot_region_get(func, else_ref, 0) == current {
              if owns_current {
                return false
              }
              owns_current = true
            }
          None => ()
        }
        if !owns_current {
          return false
        }
        current = parent
        parent = state.direct_parent[current]
      }
      _ => break
    }
  }
  if parent != target_try {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, target_try)
  for idx = 0; idx < @ir.hot_region_root_count(func, body_ref); idx = idx + 1 {
    if @ir.hot_region_get(func, body_ref, idx) == current {
      return true
    }
  }
  false
}

///|
fn flatten_exceptional_transfers_are_supported(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Rethrow =>
        if !flatten_direct_catch_all_rethrow_is_supported(func, node_id, state) {
          return false
        }
      @ir.HotOp::Delegate =>
        if !flatten_direct_delegate_is_supported(func, node_id, state) {
          return false
        }
      _ => ()
    }
  }
  true
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
    if !@ir.hot_ordered_catch_payloads_repairable(func) {
      return FlattenRunAdmission::DeferredCatchPayloadRepair
    }
    analysis.eh_repair_requirement.needs_catch_payload_tracking = false
  }
  if analysis.eh_repair_requirement.needs_exceptional_transfer_repair {
    if !flatten_exceptional_transfers_are_supported(func, analysis) {
      return FlattenRunAdmission::DeferredExceptionalTransferRepair
    }
    analysis.eh_repair_requirement.needs_exceptional_transfer_repair = false
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
  let admission_state = FlattenRewriteState::new(func)
  let before = admission_state.flatness_report
  let needs_catch_payload_repair = admission_state.eh_repair_requirement.needs_catch_payload_tracking
  match flatten_run_admission(func, before, state=Some(admission_state)) {
    FlattenRunAdmission::Admitted => ()
    FlattenRunAdmission::UpstreamHardUnsupported
    | FlattenRunAdmission::DeferredCatchPayloadRepair
    | FlattenRunAdmission::DeferredExceptionalTransferRepair
    | FlattenRunAdmission::DeferredInputfulLoop
    | FlattenRunAdmission::DeferredLegacyTry
    | FlattenRunAdmission::DeferredBranchPayload =>
      return HotPassResult::unchanged()
  }
  let mut state = admission_state
  let mut changed = false
  if needs_catch_payload_repair {
    if !@ir.hot_repair_ordered_catch_payloads(func) {
      return HotPassResult::unchanged()
    }
    state = FlattenRewriteState::new(func)
    state.eh_repair_requirement.needs_catch_payload_tracking = false
    changed = true
  }
  state.rewrites_started = true
  if flatten_rewrite_region_operands(ctx, func, state, @ir.HotRegionRef::root()) {
    changed = true
  }
  if flatten_materialize_scalar_body_result(ctx, func, state) {
    changed = true
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
