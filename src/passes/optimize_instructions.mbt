///|
pub fn optimize_instructions_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "optimize-instructions",
    requires=[@ir.HotAnalysis::use_def(), @ir.HotAnalysis::effects()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn optimize_instructions_summary() -> String {
  "Fold safe exact-instruction peepholes such as shift masks and compare-to-zero patterns."
}

///|
priv struct OptimizeInstructionsLocalFacts {
  sign_ext_bits_by_local : Array[Int]
  i32_unsigned_max_by_local : Array[Int]
  i64_unsigned_max_by_local : Array[Int64]
  mut sign_ext_ready : Bool
  mut unsigned_max_ready : Bool
}

///|
priv struct OiLocalAssignmentFact {
  live : Bool
  supported_assignment : Bool
  non_param_local : Bool
  single_value_child : Bool
  local_id : Int
  value_id : Int
  val_type : @lib.ValType?
}

///|
fn OptimizeInstructionsLocalFacts::new(
  local_count : Int,
) -> OptimizeInstructionsLocalFacts {
  {
    sign_ext_bits_by_local: Array::make(local_count, 0),
    i32_unsigned_max_by_local: Array::make(local_count, -1),
    i64_unsigned_max_by_local: Array::make(local_count, -1L),
    sign_ext_ready: false,
    unsigned_max_ready: false,
  }
}

///|
fn OptimizeInstructionsLocalFacts::sign_ext_bits_for_get(
  self : OptimizeInstructionsLocalFacts,
  local_id : Int,
) -> Int {
  if local_id >= 0 && local_id < self.sign_ext_bits_by_local.length() {
    self.sign_ext_bits_by_local[local_id]
  } else {
    0
  }
}

///|
fn OptimizeInstructionsLocalFacts::merge_sign_ext_bits_for_local(
  self : OptimizeInstructionsLocalFacts,
  local_id : Int,
  bits : Int,
) -> Unit {
  if local_id < 0 || local_id >= self.sign_ext_bits_by_local.length() {
    return
  }
  let candidate = if bits > 0 { bits } else { -1 }
  let current = self.sign_ext_bits_by_local[local_id]
  if current == 0 {
    self.sign_ext_bits_by_local[local_id] = candidate
  } else if current != candidate {
    self.sign_ext_bits_by_local[local_id] = -1
  }
}

///|
fn OptimizeInstructionsLocalFacts::finalize_sign_ext_bits(
  self : OptimizeInstructionsLocalFacts,
) -> Unit {
  for i = 0; i < self.sign_ext_bits_by_local.length(); i = i + 1 {
    if self.sign_ext_bits_by_local[i] < 0 {
      self.sign_ext_bits_by_local[i] = 0
    }
  }
}

///|
fn OptimizeInstructionsLocalFacts::i32_unsigned_max_for_get(
  self : OptimizeInstructionsLocalFacts,
  local_id : Int,
) -> Int? {
  if local_id >= 0 && local_id < self.i32_unsigned_max_by_local.length() {
    let max_value = self.i32_unsigned_max_by_local[local_id]
    if max_value >= 0 {
      Some(max_value)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn OptimizeInstructionsLocalFacts::i64_unsigned_max_for_get(
  self : OptimizeInstructionsLocalFacts,
  local_id : Int,
) -> Int64? {
  if local_id >= 0 && local_id < self.i64_unsigned_max_by_local.length() {
    let max_value = self.i64_unsigned_max_by_local[local_id]
    if max_value >= 0L {
      Some(max_value)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn OptimizeInstructionsLocalFacts::merge_i32_unsigned_max_for_local(
  self : OptimizeInstructionsLocalFacts,
  local_id : Int,
  max_value : Int?,
) -> Unit {
  if local_id < 0 || local_id >= self.i32_unsigned_max_by_local.length() {
    return
  }
  match max_value {
    Some(value) if value >= 0 =>
      if self.i32_unsigned_max_by_local[local_id] >= 0 {
        if value > self.i32_unsigned_max_by_local[local_id] {
          self.i32_unsigned_max_by_local[local_id] = value
        }
      }
    _ => self.i32_unsigned_max_by_local[local_id] = -1
  }
}

///|
fn OptimizeInstructionsLocalFacts::merge_i64_unsigned_max_for_local(
  self : OptimizeInstructionsLocalFacts,
  local_id : Int,
  max_value : Int64?,
) -> Unit {
  if local_id < 0 || local_id >= self.i64_unsigned_max_by_local.length() {
    return
  }
  match max_value {
    Some(value) if value >= 0L =>
      if self.i64_unsigned_max_by_local[local_id] >= 0L {
        if value > self.i64_unsigned_max_by_local[local_id] {
          self.i64_unsigned_max_by_local[local_id] = value
        }
      }
    _ => self.i64_unsigned_max_by_local[local_id] = -1L
  }
}

///|
fn OiLocalAssignmentFact::empty() -> OiLocalAssignmentFact {
  {
    live: false,
    supported_assignment: false,
    non_param_local: false,
    single_value_child: false,
    local_id: -1,
    value_id: -1,
    val_type: None,
  }
}

///|
fn OiLocalAssignmentFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiLocalAssignmentFact {
  // Binaryen's `LocalScanner` records local-set/tee assignments as facts that
  // later integer rewrites query, rather than each rewrite owning a separate
  // tree scanner. Keep Starshine's represented local integer assignment shape
  // explicit and shared by sign-extension and unsigned-max summaries.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return OiLocalAssignmentFact::empty()
  }
  let node = @ir.hot_node_get(func, node_id)
  let supported_assignment = match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => true
    _ => false
  }
  if !supported_assignment {
    return OiLocalAssignmentFact::empty()
  }
  let single_value_child = node.child_count == 1
  let local_id = node.imm0
  {
    live: true,
    supported_assignment,
    non_param_local: local_id >= @ir.hot_local_param_count(func),
    single_value_child,
    local_id,
    value_id: if single_value_child {
      func.children[node.child_base]
    } else {
      -1
    },
    val_type: @ir.hot_local_type(func, local_id),
  }
}

///|
fn OiLocalAssignmentFact::proves_sign_ext_integer_local(
  self : OiLocalAssignmentFact,
) -> Bool {
  if !(self.live &&
    self.supported_assignment &&
    self.non_param_local &&
    self.single_value_child) {
    return false
  }
  match self.val_type {
    Some(val_type) =>
      val_type == @lib.ValType::i32() || val_type == @lib.ValType::i64()
    None => false
  }
}

///|
fn OiLocalAssignmentFact::proves_i32_local(
  self : OiLocalAssignmentFact,
) -> Bool {
  self.live &&
  self.supported_assignment &&
  self.non_param_local &&
  self.single_value_child &&
  self.val_type == Some(@lib.ValType::i32())
}

///|
fn OiLocalAssignmentFact::proves_i64_local(
  self : OiLocalAssignmentFact,
) -> Bool {
  self.live &&
  self.supported_assignment &&
  self.non_param_local &&
  self.single_value_child &&
  self.val_type == Some(@lib.ValType::i64())
}

///|
priv struct OiRefFact {
  ref_type : @lib.RefType?
  known_null : Bool
  known_non_null : Bool
}

///|
fn OiRefFact::unknown() -> OiRefFact {
  { ref_type: None, known_null: false, known_non_null: false }
}

///|
fn OiRefFact::from_node(func : @ir.HotFunc, node_id : Int) -> OiRefFact {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiRefFact::unknown()
  }
  let node = @ir.hot_node_get(func, node_id)
  let ref_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => Some(ref_type)
    _ => None
  }
  let known_null = match node.op {
    @ir.HotOp::RefNull => true
    _ => false
  }
  let known_non_null = if known_null {
    false
  } else {
    match ref_type {
      Some(ref_type) if ref_type.is_non_nullable() => true
      _ =>
        match node.op {
          @ir.HotOp::LocalGet =>
            match @ir.hot_local_type(func, node.imm0) {
              Some(@lib.ValType::RefTypeValType(ref_type)) =>
                ref_type.is_non_nullable()
              _ => false
            }
          @ir.HotOp::RefFunc => true
          @ir.HotOp::Heap =>
            match @ir.hot_node_exact_instr(func, node_id) {
              Some(@lib.Instruction::RefI31) => true
              _ => false
            }
          _ => false
        }
    }
  }
  { ref_type, known_null, known_non_null }
}

///|
fn OiRefFact::is_known_null(self : OiRefFact) -> Bool {
  self.known_null
}

///|
fn OiRefFact::is_known_non_null(self : OiRefFact) -> Bool {
  self.known_non_null
}

///|
fn OiRefFact::type_is_non_nullable(self : OiRefFact) -> Bool {
  match self.ref_type {
    Some(ref_type) => ref_type.is_non_nullable()
    None => false
  }
}

///|
priv struct OiRefIsNullFact {
  operand_id : Int
  operand_fact : OiRefFact
  operand_effects_are_pure : Bool
}

///|
fn OiRefIsNullFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefIsNullFact? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  // Binaryen v130 `visitRefIsNull` makes the direct decision from reference
  // nullability/source facts, then preserves operand effects with a drop when
  // the operand cannot be erased. Keep that as a named fact so the visitor does
  // not own a one-off ref-null / non-null / purity cascade.
  Some({
    operand_id,
    operand_fact: OiRefFact::from_node(func, operand_id),
    operand_effects_are_pure: optimize_instructions_node_effects_are_pure(
      ctx, func, operand_id,
    ),
  })
}

///|
fn OiRefIsNullFact::known_result(self : OiRefIsNullFact) -> @lib.I32? {
  if self.operand_fact.is_known_null() {
    Some(@lib.I32(1))
  } else if self.operand_fact.is_known_non_null() {
    Some(@lib.I32(0))
  } else {
    None
  }
}

///|
fn OiRefIsNullFact::can_erase_operand(self : OiRefIsNullFact) -> Bool {
  self.operand_effects_are_pure
}

///|
priv struct OiRefIsNullSkipCastFact {
  replacement_operand_id : Int
}

///|
fn OiRefIsNullSkipCastFact::from_fact(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  fact : OiRefIsNullFact,
) -> OiRefIsNullSkipCastFact? {
  // Binaryen v130 `visitRefIsNull` calls `skipCast(curr->value)` only under
  // traps-never-happen and only after direct known-null / known-non-null folds.
  // Keep the cast-chain traversal as a fact so the visitor and rewrite plan do
  // not grow a raw opcode scanner for nullable reference casts.
  if !ctx.traps_never_happen {
    return None
  }
  let mut current_id = fact.operand_id
  let mut changed = false
  while current_id >= 0 && @ir.hot_node_is_live(func, current_id) {
    let node = @ir.hot_node_get(func, current_id)
    match node.op {
      @ir.HotOp::RefCast if node.child_count == 1 => {
        current_id = @ir.hot_child_get(func, current_id, 0)
        changed = true
        continue
      }
      @ir.HotOp::Heap if node.child_count == 1 =>
        match @ir.hot_node_exact_instr(func, current_id) {
          Some(@lib.Instruction::RefAsNonNull) => {
            current_id = @ir.hot_child_get(func, current_id, 0)
            changed = true
            continue
          }
          _ => ()
        }
      _ => ()
    }
    break
  }
  if changed {
    Some({ replacement_operand_id: current_id })
  } else {
    None
  }
}

///|
priv enum OiRefIsNullRewritePlanKind {
  RefIsNullRewriteToConst
  RefIsNullDropOperandThenConst
  RefIsNullSkipCast
}

///|
priv struct OiRefIsNullRewritePlanFact {
  kind : OiRefIsNullRewritePlanKind
  operand_id : Int
  replacement_operand_id : Int
  const_result : @lib.I32
}

///|
fn OiRefIsNullRewritePlanFact::from_fact(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  fact : OiRefIsNullFact,
) -> OiRefIsNullRewritePlanFact? {
  match fact.known_result() {
    Some(value) =>
      Some({
        kind: if fact.can_erase_operand() {
          RefIsNullRewriteToConst
        } else {
          RefIsNullDropOperandThenConst
        },
        operand_id: fact.operand_id,
        replacement_operand_id: fact.operand_id,
        const_result: value,
      })
    None =>
      match OiRefIsNullSkipCastFact::from_fact(ctx, func, fact) {
        Some(skip_fact) =>
          Some({
            kind: RefIsNullSkipCast,
            operand_id: fact.operand_id,
            replacement_operand_id: skip_fact.replacement_operand_id,
            const_result: @lib.I32(0),
          })
        None => None
      }
  }
}

///|
fn OiRefIsNullRewritePlanFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefIsNullRewritePlanFact? {
  match OiRefIsNullFact::from_node(ctx, func, node_id) {
    Some(fact) => OiRefIsNullRewritePlanFact::from_fact(ctx, func, fact)
    None => None
  }
}

///|
fn OiRefIsNullRewritePlanFact::replace_node_with_ref_is_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Unit {
  optimize_instructions_replace_with_exact_unary(
    ctx,
    func,
    node_id,
    @lib.Instruction::ref_is_null(),
    operand_id,
  )
}

///|
fn OiRefIsNullRewritePlanFact::apply(
  self : OiRefIsNullRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    RefIsNullRewriteToConst => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        self.const_result,
      )
      true
    }
    RefIsNullDropOperandThenConst => {
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        self.operand_id,
        self.const_result,
      )
      true
    }
    RefIsNullSkipCast => {
      OiRefIsNullRewritePlanFact::replace_node_with_ref_is_null(
        ctx,
        func,
        node_id,
        self.replacement_operand_id,
      )
      true
    }
  }
}

///|
priv struct OiRefLiteralFact {
  i31_literal : Bool
  func_literal : Bool
}

///|
fn OiRefLiteralFact::none() -> OiRefLiteralFact {
  { i31_literal: false, func_literal: false }
}

///|
fn OiRefLiteralFact::i31() -> OiRefLiteralFact {
  { i31_literal: true, func_literal: false }
}

///|
fn OiRefLiteralFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefLiteralFact {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiRefLiteralFact::none()
  }
  let node = @ir.hot_node_get(func, node_id)
  let i31_literal = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefI31) => true
    _ => false
  }
  let func_literal = match node.op {
    @ir.HotOp::RefFunc => true
    _ => false
  }
  { i31_literal, func_literal }
}

///|
fn OiRefLiteralFact::is_known_non_null(self : OiRefLiteralFact) -> Bool {
  self.i31_literal || self.func_literal
}

///|
fn OiRefLiteralFact::is_i31(self : OiRefLiteralFact) -> Bool {
  self.i31_literal
}

///|
fn OiRefLiteralFact::matches_target(
  self : OiRefLiteralFact,
  target : @lib.HeapType,
) -> Bool {
  (self.func_literal && optimize_instructions_ref_func_matches_target(target)) ||
  (self.i31_literal && optimize_instructions_ref_i31_matches_target(target))
}

///|
fn OiRefLiteralFact::i31_cannot_match_target(
  self : OiRefLiteralFact,
  target : @lib.HeapType,
) -> Bool {
  self.i31_literal && optimize_instructions_ref_i31_cannot_match_target(target)
}

///|
priv struct OiNullTrapFact {
  traps_on_null : Bool
  operand_known_null : Bool
  operand_known_non_null : Bool
}

///|
fn OiNullTrapFact::for_operand(
  func : @ir.HotFunc,
  operand_id : Int,
  traps_on_null~ : Bool,
) -> OiNullTrapFact {
  let ref_fact = OiRefFact::from_node(func, operand_id)
  {
    traps_on_null,
    operand_known_null: ref_fact.is_known_null(),
    operand_known_non_null: ref_fact.is_known_non_null(),
  }
}

///|
fn OiNullTrapFact::can_replace_parent_with_unreachable(
  self : OiNullTrapFact,
) -> Bool {
  self.traps_on_null && self.operand_known_null
}

///|
fn OiNullTrapFact::can_skip_explicit_non_null_check(
  self : OiNullTrapFact,
) -> Bool {
  self.operand_known_non_null
}

///|
fn optimize_instructions_region_tail_id(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int? {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return None
  }
  let tail_id = @ir.hot_region_get(func, region_ref, root_count - 1)
  if @ir.hot_node_is_live(func, tail_id) {
    Some(tail_id)
  } else {
    None
  }
}

///|
fn optimize_instructions_region_explicitly_does_not_fallthrough(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  match optimize_instructions_region_tail_id(func, region_ref) {
    Some(tail_id) =>
      match @ir.hot_node_get(func, tail_id).op {
        @ir.HotOp::Unreachable => true
        _ => false
      }
    None => false
  }
}

///|
priv struct OiFallthroughTailFact {
  live : Bool
  child_count : Int
  branch_to_fallthrough_child : Bool
}

///|
fn OiFallthroughTailFact::empty() -> OiFallthroughTailFact {
  { live: false, child_count: 0, branch_to_fallthrough_child: false }
}

///|
fn OiFallthroughTailFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiFallthroughTailFact {
  // Binaryen's Properties::getImmediateFallthrough treats br_on_* as letting
  // their reference child fall through. Starshine's represented region path
  // keeps that proof as a tail fact so descriptor/ref fallthrough typing does
  // not own an opcode helper.
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiFallthroughTailFact::empty()
  }
  let child_count = @ir.hot_child_count(func, node_id)
  let branch_to_fallthrough_child = match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => child_count > 0
    _ => false
  }
  { live: true, child_count, branch_to_fallthrough_child }
}

///|
fn OiFallthroughTailFact::proves_branch_to_fallthrough_child(
  self : OiFallthroughTailFact,
) -> Bool {
  self.live && self.child_count > 0 && self.branch_to_fallthrough_child
}

///|
priv struct OiRefFallthroughRegionFact {
  root_count : Int
  tail_id : Int
  has_branch_control : Bool
  prefix_has_branch_control : Bool
  tail_branches_to_fallthrough_child : Bool
  usable_tail : Bool
  ref_type : @lib.RefType?
}

///|
fn OiRefFallthroughRegionFact::empty() -> OiRefFallthroughRegionFact {
  {
    root_count: 0,
    tail_id: -1,
    has_branch_control: false,
    prefix_has_branch_control: false,
    tail_branches_to_fallthrough_child: false,
    usable_tail: false,
    ref_type: None,
  }
}

///|
fn OiRefFallthroughRegionFact::from_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> OiRefFallthroughRegionFact {
  // Binaryen's Properties::getFallthroughType descends through block/loop/if
  // tails, but the represented descriptor path must not hide earlier branch
  // control unless the live tail itself is the branch-on-reference fallthrough.
  // Carry the region-wide branch-control summary, prefix summary, tail proof,
  // and resulting type as one fact instead of scattered fallthrough helpers.
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let tail_id = match optimize_instructions_region_tail_id(func, region_ref) {
    Some(tail_id) => tail_id
    None => return OiRefFallthroughRegionFact::empty()
  }
  let has_branch_control = OiDescriptorBranchControlRegionFact::from_region(
    func,
    region_ref.holder,
    region_ref,
  ).proves_has_branch_control()
  let prefix_has_branch_control = OiDescriptorBranchControlRegionFact::from_region_prefix_excluding_tail(
    func,
    region_ref.holder,
    region_ref,
  ).proves_has_branch_control()
  let tail_branches_to_fallthrough_child = OiFallthroughTailFact::from_node(
    func, tail_id,
  ).proves_branch_to_fallthrough_child()
  let usable_tail = !has_branch_control ||
    (tail_branches_to_fallthrough_child && !prefix_has_branch_control)
  let ref_type = if usable_tail {
    OiRefFallthroughFact::from_node(ctx, func, tail_id).ref_type
  } else {
    None
  }
  {
    root_count,
    tail_id,
    has_branch_control,
    prefix_has_branch_control,
    tail_branches_to_fallthrough_child,
    usable_tail,
    ref_type,
  }
}

///|
fn OiRefFallthroughRegionFact::proven_ref_type(
  self : OiRefFallthroughRegionFact,
) -> @lib.RefType? {
  ignore(self.root_count)
  if self.tail_id >= 0 &&
    self.usable_tail &&
    (
      !self.has_branch_control ||
      (
        self.tail_branches_to_fallthrough_child &&
        !self.prefix_has_branch_control
      )
    ) {
    self.ref_type
  } else {
    None
  }
}

///|
priv struct OiRefFallthroughFact {
  ref_type : @lib.RefType?
}

///|
fn optimize_instructions_node_ref_result_type(
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.RefType? {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => Some(ref_type)
    _ => None
  }
}

///|
priv struct OiHeapSubtypeFact {
  known : Bool
}

///|
fn OiHeapSubtypeFact::from_heaps(
  ctx : HotPassContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> OiHeapSubtypeFact {
  if source == target {
    return { known: true }
  }
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return { known: false }
  }
  {
    known: OiHeapSubtypeFact::proves_subtype_with_fuel(
      module_ctx, source, target, 64,
    ),
  }
}

///|
fn OiHeapSubtypeFact::proves_subtype_with_fuel(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if source == target {
    return true
  }
  if fuel <= 0 {
    return false
  }
  let source_idx = match source {
    @lib.HeapType(source_idx) => source_idx
    _ => return false
  }
  match @ir.hot_module_resolve_subtype(module_ctx, source_idx) {
    Some(subtype) => {
      for super_idx in subtype.super_types() {
        if OiHeapSubtypeFact::proves_subtype_with_fuel(
            module_ctx,
            @lib.HeapType::new(super_idx),
            target,
            fuel - 1,
          ) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn OiHeapSubtypeFact::proves_known_subtype(self : OiHeapSubtypeFact) -> Bool {
  self.known
}

///|
priv struct OiConcreteSourceTargetOverlapFact {
  no_target_overlap : Bool
}

///|
fn OiConcreteSourceTargetOverlapFact::from_heaps(
  module_ctx : @ir.HotModuleContext?,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> OiConcreteSourceTargetOverlapFact {
  // Binaryen proves a ref.test/ref.cast miss for concrete sources by checking
  // that no declared subtype can simultaneously flow to both source and target.
  // Keep the expensive module walk behind an explicit fact rather than a
  // caller-owned subtype scanner.
  let ctx = match module_ctx {
    Some(ctx) => ctx
    None => return { no_target_overlap: false }
  }
  match source {
    @lib.HeapType::HeapType(_) => ()
    _ => return { no_target_overlap: false }
  }
  if optimize_instructions_heap_matches_target(ctx, source, target, 512) {
    return { no_target_overlap: false }
  }
  let subtype_count = @ir.hot_module_subtype_count(ctx)
  for i = 0; i < subtype_count; i = i + 1 {
    let heap = @lib.HeapType::new(@lib.TypeIdx::new(i.reinterpret_as_uint()))
    if optimize_instructions_heap_matches_target(ctx, heap, source, 512) &&
      optimize_instructions_heap_matches_target(ctx, heap, target, 512) {
      return { no_target_overlap: false }
    }
  }
  { no_target_overlap: true }
}

///|
fn OiConcreteSourceTargetOverlapFact::proves_no_target_overlap(
  self : OiConcreteSourceTargetOverlapFact,
) -> Bool {
  self.no_target_overlap
}

///|
priv struct OiFinalHeapFact {
  final_heap : Bool
}

///|
fn OiFinalHeapFact::from_heap(
  module_ctx : @ir.HotModuleContext,
  heap : @lib.HeapType,
) -> OiFinalHeapFact {
  let final_heap = match heap {
    @lib.HeapType::HeapType(type_idx) =>
      match @ir.hot_module_resolve_subtype(module_ctx, type_idx) {
        Some(@lib.CompTypeSubType(_, _)) => true
        Some(@lib.SubType(true, _, _, _)) => true
        _ => false
      }
    _ => false
  }
  { final_heap, }
}

///|
fn OiFinalHeapFact::proves_final_heap(self : OiFinalHeapFact) -> Bool {
  self.final_heap
}

///|
priv struct OiHeapRelationFact {
  same_heap : Bool
  i31_matches_target : Bool
  i31_cannot_match_target : Bool
  abs_struct_array_matches_target : Bool
  abs_struct_array_disjoint : Bool
  module_heap_matches_target : Bool
  known_subtype : Bool
  concrete_source_has_no_target_overlap : Bool
  both_concrete_heaps : Bool
}

///|
fn OiHeapRelationFact::from_heaps(
  ctx : HotPassContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> OiHeapRelationFact {
  let module_heap_matches_target = match ctx.module_ctx {
    Some(module_ctx) =>
      optimize_instructions_heap_matches_target(module_ctx, source, target, 512)
    None => false
  }
  let both_concrete_heaps = match (source, target) {
    (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => true
    _ => false
  }
  {
    same_heap: source == target,
    i31_matches_target: source == @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
    optimize_instructions_ref_i31_matches_target(target),
    i31_cannot_match_target: source ==
    @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
    optimize_instructions_ref_i31_cannot_match_target(target),
    abs_struct_array_matches_target: optimize_instructions_abs_struct_array_matches_target(
      source, target,
    ),
    abs_struct_array_disjoint: optimize_instructions_abs_struct_array_disjoint(
      source, target,
    ),
    module_heap_matches_target,
    known_subtype: OiHeapSubtypeFact::from_heaps(ctx, source, target).proves_known_subtype(),
    concrete_source_has_no_target_overlap: OiConcreteSourceTargetOverlapFact::from_heaps(
      ctx.module_ctx,
      source,
      target,
    ).proves_no_target_overlap(),
    both_concrete_heaps,
  }
}

///|
fn OiHeapRelationFact::known_match_without_full_subtyping(
  self : OiHeapRelationFact,
) -> Bool {
  self.same_heap ||
  self.i31_matches_target ||
  self.abs_struct_array_matches_target
}

///|
fn OiHeapRelationFact::known_match_target(self : OiHeapRelationFact) -> Bool {
  self.known_match_without_full_subtyping() || self.module_heap_matches_target
}

///|
fn OiHeapRelationFact::known_miss_target(self : OiHeapRelationFact) -> Bool {
  self.i31_cannot_match_target ||
  self.abs_struct_array_disjoint ||
  self.concrete_source_has_no_target_overlap
}

///|
fn OiHeapRelationFact::known_abs_struct_array_disjoint(
  self : OiHeapRelationFact,
) -> Bool {
  self.abs_struct_array_disjoint
}

///|
fn OiHeapRelationFact::known_strict_concrete_subtype(
  self : OiHeapRelationFact,
) -> Bool {
  self.both_concrete_heaps && !self.same_heap && self.known_subtype
}

///|
fn OiHeapRelationFact::strict_concrete_heap_matches_target(
  self : OiHeapRelationFact,
) -> Bool {
  self.both_concrete_heaps && !self.same_heap && self.module_heap_matches_target
}

///|
fn OiHeapRelationFact::concrete_source_matches_nullable_exact_target_only_as_null(
  self : OiHeapRelationFact,
  source_nullable : Bool,
  source_exact : Bool,
  target_nullable : Bool,
) -> Bool {
  target_nullable &&
  source_nullable &&
  self.both_concrete_heaps &&
  !self.same_heap &&
  (source_exact || self.module_heap_matches_target)
}

///|
fn OiHeapRelationFact::matches_or_strict_subtypes_heap(
  self : OiHeapRelationFact,
  source_nullable : Bool,
  source_exact : Bool,
) -> (Bool, Bool)? {
  if self.same_heap {
    Some((source_nullable, source_exact))
  } else if self.known_strict_concrete_subtype() {
    // A strict subtype operand proves heap compatibility, but it does not
    // prove the value is an exact instance of the supertype target.
    Some((source_nullable, false))
  } else {
    None
  }
}

///|
fn optimize_instructions_ref_fallthrough_lower_bound(
  ctx : HotPassContext,
  outer : @lib.RefType,
  inner : @lib.RefType,
) -> @lib.RefType? {
  let outer_heap = outer.get_heap_type()
  let inner_heap = inner.get_heap_type()
  let nullable = outer.is_nullable() && inner.is_nullable()
  if inner_heap == outer_heap {
    return Some(
      @lib.RefType::new(
        nullable,
        inner_heap,
        exact=outer.is_exact() || inner.is_exact(),
      ),
    )
  }
  if outer.is_exact() || inner.is_exact() {
    return None
  }
  if optimize_instructions_ref_type_heap_matches_target(ctx, inner, outer_heap) {
    return Some(@lib.RefType::new(nullable, inner_heap, exact=inner.is_exact()))
  }
  if optimize_instructions_ref_type_heap_matches_target(ctx, outer, inner_heap) {
    return Some(@lib.RefType::new(nullable, outer_heap, exact=outer.is_exact()))
  }
  None
}

///|
fn OiRefFallthroughFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefFallthroughFact {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return { ref_type: None }
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::RefCast if node.child_count == 1 => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match
        (
          optimize_instructions_node_ref_result_type(func, node_id),
          OiRefFallthroughFact::from_node(ctx, func, child_id).ref_type,
        ) {
        (Some(outer), Some(inner)) =>
          match
            optimize_instructions_ref_fallthrough_lower_bound(ctx, outer, inner) {
            Some(ref_type) => return { ref_type: Some(ref_type) }
            None => ()
          }
        _ => ()
      }
    }
    @ir.HotOp::Heap if node.child_count == 1 =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefAsNonNull) => {
          let child_id = @ir.hot_child_get(func, node_id, 0)
          match
            (
              optimize_instructions_node_ref_result_type(func, node_id),
              OiRefFallthroughFact::from_node(ctx, func, child_id).ref_type,
            ) {
            (Some(outer), Some(inner)) =>
              match
                optimize_instructions_ref_fallthrough_lower_bound(
                  ctx, outer, inner,
                ) {
                Some(ref_type) => return { ref_type: Some(ref_type) }
                None => ()
              }
            _ => ()
          }
        }
        _ => ()
      }
    @ir.HotOp::LocalTee if node.child_count == 1 => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match OiRefFallthroughFact::from_node(ctx, func, child_id).ref_type {
        Some(ref_type) => return { ref_type: Some(ref_type) }
        None => ()
      }
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail if node.child_count > 0 => {
      let child_id = @ir.hot_child_get(func, node_id, node.child_count - 1)
      match
        (
          optimize_instructions_node_ref_result_type(func, node_id),
          OiRefFallthroughFact::from_node(ctx, func, child_id).ref_type,
        ) {
        (Some(outer), Some(inner)) =>
          match
            optimize_instructions_ref_fallthrough_lower_bound(ctx, outer, inner) {
            Some(ref_type) => return { ref_type: Some(ref_type) }
            None => ()
          }
        _ => ()
      }
    }
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      match
        OiRefFallthroughRegionFact::from_region(ctx, func, body_ref).proven_ref_type() {
        Some(ref_type) => return { ref_type: Some(ref_type) }
        None => ()
      }
    }
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let then_ref = @ir.hot_region_then_ref(func, node_id)
          let then_stops = optimize_instructions_region_explicitly_does_not_fallthrough(
            func, then_ref,
          )
          let else_stops = optimize_instructions_region_explicitly_does_not_fallthrough(
            func, else_ref,
          )
          if then_stops && !else_stops {
            match
              OiRefFallthroughRegionFact::from_region(ctx, func, else_ref).proven_ref_type() {
              Some(ref_type) => return { ref_type: Some(ref_type) }
              None => ()
            }
          } else if else_stops && !then_stops {
            match
              OiRefFallthroughRegionFact::from_region(ctx, func, then_ref).proven_ref_type() {
              Some(ref_type) => return { ref_type: Some(ref_type) }
              None => ()
            }
          }
        }
        None => ()
      }
    _ => ()
  }
  { ref_type: optimize_instructions_node_ref_result_type(func, node_id) }
}

///|
priv struct OiRefProducerFact {
  ref_type : @lib.RefType?
}

///|
fn OiRefProducerFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefProducerFact {
  let node = @ir.hot_node_get(func, node_id)
  let ref_type = match node.op {
    @ir.HotOp::Call if node.imm0 >= 0 =>
      match ctx.module_ctx {
        Some(module_ctx) =>
          match
            @ir.hot_module_resolve_func_type(
              module_ctx,
              @lib.FuncIdx::new(node.imm0.reinterpret_as_uint()),
            ) {
            Some(@lib.FuncType(_, [@lib.ValType::RefTypeValType(ref_type)])) =>
              Some(ref_type)
            _ => None
          }
        None => None
      }
    @ir.HotOp::CallIndirect | @ir.HotOp::CallRef =>
      match ctx.module_ctx {
        Some(module_ctx) => {
          let sig = @ir.hot_call_sig_get(func, node.imm0)
          match
            @ir.hot_module_resolve_type_func_type(module_ctx, sig.type_idx) {
            Some(@lib.FuncType(_, [@lib.ValType::RefTypeValType(ref_type)])) =>
              Some(ref_type)
            _ => None
          }
        }
        None => None
      }
    _ => OiRefFallthroughFact::from_node(ctx, func, node_id).ref_type
  }
  { ref_type, }
}

///|
fn OiRefProducerFact::non_null_matches_target(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      ref_type.is_non_nullable() &&
      OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_match_target()
    None => false
  }
}

///|
fn OiRefProducerFact::nullable_matches_target(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      ref_type.is_nullable() &&
      OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_match_target()
    None => false
  }
}

///|
fn OiRefProducerFact::matches_exact_test_target(
  self : OiRefProducerFact,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      ref_type.is_exact() &&
      ref_type.get_heap_type() == target &&
      (target_nullable || ref_type.is_non_nullable())
    None => false
  }
}

///|
fn OiRefProducerFact::misses_target(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_miss_target() &&
      (ref_type.is_non_nullable() || !target_nullable)
    None => false
  }
}

///|
fn OiRefProducerFact::misses_exact_target(
  self : OiRefProducerFact,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      ref_type.is_exact() &&
      ref_type.get_heap_type() != target &&
      (ref_type.is_non_nullable() || !target_nullable)
    None => false
  }
}

///|
fn OiRefProducerFact::misses_exact_target_by_strict_subtype(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.ref_type {
    Some(ref_type) => {
      let relation = OiHeapRelationFact::from_heaps(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
      (ref_type.is_non_nullable() || !target_nullable) &&
      relation.strict_concrete_heap_matches_target()
    }
    None => false
  }
}

///|
fn OiRefProducerFact::matches_nullable_exact_target_only_as_null(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  if !target_nullable {
    return false
  }
  match self.ref_type {
    Some(ref_type) => {
      let relation = OiHeapRelationFact::from_heaps(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
      relation.concrete_source_matches_nullable_exact_target_only_as_null(
        ref_type.is_nullable(),
        ref_type.is_exact(),
        target_nullable,
      )
    }
    None => false
  }
}

///|
fn OiRefProducerFact::has_final_heap(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match self.ref_type {
    Some(ref_type) =>
      ref_type.get_heap_type() == target &&
      OiFinalHeapFact::from_heap(module_ctx, target).proves_final_heap()
    None => false
  }
}

///|
fn OiRefProducerFact::matches_final_exact_test_target(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      (target_nullable || ref_type.is_non_nullable()) &&
      self.has_final_heap(ctx, target)
    None => false
  }
}

///|
fn OiRefProducerFact::exact_non_null_heap(
  self : OiRefProducerFact,
  heap : @lib.HeapType,
) -> Bool {
  match self.ref_type {
    Some(ref_type) =>
      ref_type.is_non_nullable() &&
      ref_type.is_exact() &&
      ref_type.get_heap_type() == heap
    None => false
  }
}

///|
fn OiRefProducerFact::exact_heap(
  self : OiRefProducerFact,
  heap : @lib.HeapType,
) -> Bool {
  match self.ref_type {
    Some(ref_type) => ref_type.is_exact() && ref_type.get_heap_type() == heap
    None => false
  }
}

///|
fn OiRefProducerFact::matches_or_subtypes_heap(
  self : OiRefProducerFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> (Bool, Bool)? {
  match self.ref_type {
    Some(ref_type) => {
      let source = ref_type.get_heap_type()
      OiHeapRelationFact::from_heaps(ctx, source, target).matches_or_strict_subtypes_heap(
        ref_type.is_nullable(),
        ref_type.is_exact(),
      )
    }
    None => None
  }
}

///|
priv struct OiDescriptorTypeFact {
  exact_described_heap : @lib.HeapType?
}

///|
fn OiDescriptorTypeFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorTypeFact {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return { exact_described_heap: None }
  }
  let descriptor_idx = match
    OiRefProducerFact::from_node(ctx, func, node_id).ref_type {
    Some(ref_type) if ref_type.is_non_nullable() && ref_type.is_exact() =>
      match ref_type.get_heap_type() {
        @lib.HeapType(descriptor_idx) => descriptor_idx
        _ => return { exact_described_heap: None }
      }
    _ => return { exact_described_heap: None }
  }
  let exact_described_heap = match
    @ir.hot_module_resolve_subtype(module_ctx, descriptor_idx) {
    Some(subtype) =>
      match subtype.describes_type() {
        Some(described_idx) => Some(@lib.HeapType::new(described_idx))
        None => None
      }
    None => None
  }
  { exact_described_heap, }
}

///|
fn OiDescriptorTypeFact::exactly_describes(
  self : OiDescriptorTypeFact,
  heap : @lib.HeapType,
) -> Bool {
  match self.exact_described_heap {
    Some(described_heap) => described_heap == heap
    None => false
  }
}

///|
priv struct OiDescriptorOperandFact {
  type_fact : OiDescriptorTypeFact
  traps_without_effects : Bool
  can_erase : Bool
  should_localize_when_skipped : Bool
  may_drop_exactness_for_tnh_escaping_ref_get_desc : Bool
}

///|
priv struct OiDescriptorExactnessDropFact {
  ref_get_desc_operand : Bool
  escaping_branch_control : Bool
  may_drop_exactness : Bool
}

///|
fn OiDescriptorExactnessDropFact::from_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorExactnessDropFact {
  // Binaryen's descriptor-cast TNH skip may drop exactness when the descriptor
  // operand is a ref.get_desc whose preserved children can escape through
  // branch control. Keep that guard as a fact over the descriptor operand and
  // the shared branch-control summary instead of a helper-level predicate.
  let ref_get_desc_operand = match OiRefGetDescFact::from_node(func, node_id) {
    Some(_) => true
    None => false
  }
  let escaping_branch_control = ref_get_desc_operand &&
    OiDescriptorBranchControlFact::from_node(func, node_id, node_id).proves_has_escaping_branch_control()
  {
    ref_get_desc_operand,
    escaping_branch_control,
    may_drop_exactness: ref_get_desc_operand && escaping_branch_control,
  }
}

///|
fn OiDescriptorExactnessDropFact::proves_may_drop_exactness(
  self : OiDescriptorExactnessDropFact,
) -> Bool {
  self.ref_get_desc_operand &&
  self.escaping_branch_control &&
  self.may_drop_exactness
}

///|
fn OiDescriptorOperandFact::from_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorOperandFact {
  {
    type_fact: OiDescriptorTypeFact::from_node(ctx, func, node_id),
    traps_without_effects: OiDescriptorOperandTrapFact::from_operand(
      func, node_id,
    ).proves_traps_without_effects(),
    can_erase: OiDescriptorOperandEraseFact::from_operand(
      ctx, func, dead, node_id,
    ).proves_can_erase(),
    should_localize_when_skipped: OiDescriptorOperandSkipLocalizationFact::from_operand(
      func, node_id,
    ).proves_should_localize_when_skipped(),
    may_drop_exactness_for_tnh_escaping_ref_get_desc: OiDescriptorExactnessDropFact::from_operand(
      func, node_id,
    ).proves_may_drop_exactness(),
  }
}

///|
priv struct OiRefGetDescTrapFact {
  ref_get_desc : Bool
  child_unreachable : Bool
  explicit_nullable_child : Bool
  nullable_child_known_null : Bool
  traps_without_effects : Bool
}

///|
fn OiRefGetDescTrapFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefGetDescTrapFact {
  // Binaryen v130 treats `ref.get_desc(unreachable)` and
  // `ref.get_desc(ref.as_non_null(ref.null ...))` as descriptor operands that
  // can trap before any side effect. Record the trap proof separately from the
  // descriptor operand fact so callers do not ask `OiRefGetDescFact` for an
  // ad hoc helper-level decision.
  let get_desc_fact = match OiRefGetDescFact::from_node(func, node_id) {
    Some(fact) => fact
    None =>
      return {
        ref_get_desc: false,
        child_unreachable: false,
        explicit_nullable_child: false,
        nullable_child_known_null: false,
        traps_without_effects: false,
      }
  }
  let child_unreachable = get_desc_fact.child_is_unreachable(func)
  let (explicit_nullable_child, nullable_child_known_null) = match
    get_desc_fact.explicit_nullable_child() {
    Some(nullable_child) =>
      (
        true,
        match @ir.hot_node_get(func, nullable_child).op {
          @ir.HotOp::RefNull => true
          _ => false
        },
      )
    None => (false, false)
  }
  {
    ref_get_desc: true,
    child_unreachable,
    explicit_nullable_child,
    nullable_child_known_null,
    traps_without_effects: child_unreachable ||
    (explicit_nullable_child && nullable_child_known_null),
  }
}

///|
fn OiRefGetDescTrapFact::proves_traps_without_effects(
  self : OiRefGetDescTrapFact,
) -> Bool {
  self.ref_get_desc &&
  self.traps_without_effects &&
  (
    self.child_unreachable ||
    (self.explicit_nullable_child && self.nullable_child_known_null)
  )
}

///|
priv struct OiDescriptorOperandTrapFact {
  direct_unreachable : Bool
  ref_get_desc_traps_without_effects : Bool
  traps_without_effects : Bool
}

///|
fn OiDescriptorOperandTrapFact::from_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorOperandTrapFact {
  // Descriptor casts/tests can become `unreachable` when the descriptor operand
  // itself is already an unconditional trap with no preceding side effects.
  // Keep the direct-unreachable and ref.get_desc trap cases as fact fields
  // instead of a descriptor-operand helper cascade.
  let direct_unreachable = match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable => true
    _ => false
  }
  let ref_get_desc_traps_without_effects = OiRefGetDescTrapFact::from_node(
    func, node_id,
  ).proves_traps_without_effects()
  {
    direct_unreachable,
    ref_get_desc_traps_without_effects,
    traps_without_effects: direct_unreachable ||
    ref_get_desc_traps_without_effects,
  }
}

///|
fn OiDescriptorOperandTrapFact::proves_traps_without_effects(
  self : OiDescriptorOperandTrapFact,
) -> Bool {
  self.traps_without_effects &&
  (self.direct_unreachable || self.ref_get_desc_traps_without_effects)
}

///|
priv struct OiDescriptorOperandSkipLocalizationFact {
  call_root : Bool
  call_ref_root : Bool
  ref_get_desc_root : Bool
  should_localize_when_skipped : Bool
}

///|
fn OiDescriptorOperandSkipLocalizationFact::from_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorOperandSkipLocalizationFact {
  // Binaryen's descriptor TNH skip path uses ChildLocalizer-like decisions to
  // preserve descriptor operand evaluation when the descriptor is a call-like or
  // ref.get_desc producer. Keep Starshine's represented producer subset as data
  // so skip/replacement code does not own an opcode whitelist.
  let node = @ir.hot_node_get(func, node_id)
  let call_root = match node.op {
    @ir.HotOp::Call => true
    _ => false
  }
  let call_ref_root = match node.op {
    @ir.HotOp::CallRef => true
    _ => false
  }
  let ref_get_desc_root = match OiRefGetDescFact::from_node(func, node_id) {
    Some(_) => true
    None => false
  }
  {
    call_root,
    call_ref_root,
    ref_get_desc_root,
    should_localize_when_skipped: call_root ||
    call_ref_root ||
    ref_get_desc_root,
  }
}

///|
fn OiDescriptorOperandSkipLocalizationFact::proves_should_localize_when_skipped(
  self : OiDescriptorOperandSkipLocalizationFact,
) -> Bool {
  self.should_localize_when_skipped &&
  (self.call_root || self.call_ref_root || self.ref_get_desc_root)
}

///|
priv struct OiRefTestFact {
  nullable : Bool
  exact : Bool
  target : @lib.HeapType
  operand_id : Int
  descriptor_style : Bool
}

///|
fn OiRefTestFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefTestFact? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  let (nullable, exact, target, descriptor_style) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefTest(nullable, exact, target)) =>
      (nullable, exact, target, false)
    Some(@lib.Instruction::RefTestDesc(nullable, target)) =>
      (nullable, false, target, true)
    _ => return None
  }
  Some({
    nullable,
    exact,
    target,
    operand_id: @ir.hot_child_get(func, node_id, 0),
    descriptor_style,
  })
}

///|
fn OiRefTestFact::known_null_result(self : OiRefTestFact) -> @lib.I32 {
  ignore(self.descriptor_style)
  if self.nullable {
    @lib.I32(1)
  } else {
    @lib.I32(0)
  }
}

///|
priv struct OiRefTestTighteningFact {
  narrowed_ref_type : @lib.RefType
}

///|
priv struct OiOrdinaryRefTestTighteningFact {
  narrowed_ref_type : @lib.RefType
}

///|
priv struct OiDescriptorRefTestTighteningFact {
  boundary_only : Bool
}

///|
fn OiOrdinaryRefTestTighteningFact::from_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  test_fact : OiRefTestFact,
) -> OiOrdinaryRefTestTighteningFact? {
  // Binaryen v130 `visitRefTest` first intersects the ordinary test cast type
  // with `getFallthroughType(ref)` using `Type::getGreatestLowerBound`, then
  // evaluates the cast check. Keep the represented ordinary-test GLB/nullability
  // rule as a fact over the test target and operand fallthrough type instead of
  // an opcode-local immediate scanner.
  let current_ref_type = @lib.RefType::new(
    test_fact.nullable,
    test_fact.target,
    exact=test_fact.exact,
  )
  let fallthrough_ref_type = match
    OiRefFallthroughFact::from_node(ctx, func, test_fact.operand_id).ref_type {
    Some(ref_type) => ref_type
    None => return None
  }
  match
    optimize_instructions_ref_fallthrough_lower_bound(
      ctx, current_ref_type, fallthrough_ref_type,
    ) {
    Some(narrowed_ref_type) if narrowed_ref_type != current_ref_type =>
      Some({ narrowed_ref_type, })
    _ => None
  }
}

///|
fn OiDescriptorRefTestTighteningFact::from_test(
  test_fact : OiRefTestFact,
) -> OiDescriptorRefTestTighteningFact? {
  // Binaryen applies the same `visitRefTest` fallthrough/GLB phase to descriptor
  // tests, but Starshine cannot yet construct a validated descriptor-test GLB
  // fixture for same-shape or bottom-target cases. Preserve the boundary as a
  // named fact so descriptor tightening can be reopened here with valid fixtures
  // instead of living as an implicit `descriptor_style` escape in the ordinary
  // ref-test path.
  if test_fact.descriptor_style {
    Some({ boundary_only: true })
  } else {
    None
  }
}

///|
fn OiDescriptorRefTestTighteningFact::proves_boundary_only(
  self : OiDescriptorRefTestTighteningFact,
) -> Bool {
  self.boundary_only
}

///|
fn OiRefTestTighteningFact::from_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  test_fact : OiRefTestFact,
) -> OiRefTestTighteningFact? {
  if test_fact.descriptor_style {
    match OiDescriptorRefTestTighteningFact::from_test(test_fact) {
      Some(fact) => ignore(fact.proves_boundary_only())
      None => ()
    }
    return None
  }
  match OiOrdinaryRefTestTighteningFact::from_test(ctx, func, test_fact) {
    Some(fact) => Some({ narrowed_ref_type: fact.narrowed_ref_type })
    None => None
  }
}

///|
priv struct OiRefTestOperandFact {
  ref_fact : OiRefFact
  producer_fact : OiRefProducerFact
  literal_fact : OiRefLiteralFact
  source_type : @lib.RefType?
}

///|
fn OiRefTestOperandFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  operand_id : Int,
) -> OiRefTestOperandFact {
  let ref_fact = OiRefFact::from_node(func, operand_id)
  let producer_fact = OiRefProducerFact::from_node(ctx, func, operand_id)
  {
    ref_fact,
    producer_fact,
    literal_fact: OiRefLiteralFact::from_node(func, operand_id),
    source_type: ref_fact.ref_type,
  }
}

///|
fn OiRefTestOperandFact::is_known_null(self : OiRefTestOperandFact) -> Bool {
  self.ref_fact.is_known_null()
}

///|
fn OiRefTestOperandFact::descriptor_matches_or_subtypes_heap(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> (Bool, Bool)? {
  self.producer_fact.matches_or_subtypes_heap(ctx, target)
}

///|
fn OiRefTestOperandFact::heap_matches_target_without_subtyping(
  ctx : HotPassContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  OiHeapRelationFact::from_heaps(ctx, source, target).known_match_without_full_subtyping()
}

///|
fn OiRefTestOperandFact::source_has_exact_heap(
  self : OiRefTestOperandFact,
  target : @lib.HeapType,
) -> Bool {
  match self.source_type {
    Some(ref_type) => ref_type.is_exact() && ref_type.get_heap_type() == target
    None => false
  }
}

///|
fn OiRefTestOperandFact::source_has_final_heap(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match self.source_type {
    Some(ref_type) =>
      ref_type.get_heap_type() == target &&
      OiFinalHeapFact::from_heap(module_ctx, target).proves_final_heap()
    None => false
  }
}

///|
fn OiRefTestOperandFact::nullable_matches_target(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_nullable() &&
      OiRefTestOperandFact::heap_matches_target_without_subtyping(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
    None => false
  }
}

///|
fn OiRefTestOperandFact::matches_exact_test_target(
  self : OiRefTestOperandFact,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_exact() &&
      ref_type.get_heap_type() == target &&
      (target_nullable || ref_type.is_non_nullable())
    None => false
  }
}

///|
fn OiRefTestOperandFact::matches_final_exact_test_target(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      (target_nullable || ref_type.is_non_nullable()) &&
      self.source_has_final_heap(ctx, target)
    None => false
  }
}

///|
fn OiRefTestOperandFact::matches_nullable_exact_target_only_as_null(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  if !target_nullable {
    return false
  }
  match self.source_type {
    Some(ref_type) => {
      let relation = OiHeapRelationFact::from_heaps(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
      relation.concrete_source_matches_nullable_exact_target_only_as_null(
        ref_type.is_nullable(),
        ref_type.is_exact(),
        target_nullable,
      )
    }
    None => false
  }
}

///|
fn OiRefTestOperandFact::non_null_matches_target(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  if self.literal_fact.matches_target(target) {
    return true
  }
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_non_nullable() &&
      OiRefTestOperandFact::heap_matches_target_without_subtyping(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
    None => false
  }
}

///|
fn OiRefTestOperandFact::misses_target(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  if self.literal_fact.i31_cannot_match_target(target) {
    return true
  }
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_non_nullable() &&
      OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_miss_target()
    None => false
  }
}

///|
fn OiRefTestOperandFact::null_or_known_miss_for_non_null_target(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_miss_target()
    None => false
  }
}

///|
fn OiRefTestOperandFact::misses_exact_target(
  self : OiRefTestOperandFact,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_exact() &&
      ref_type.get_heap_type() != target &&
      (ref_type.is_non_nullable() || !target_nullable)
    None => false
  }
}

///|
fn OiRefTestOperandFact::misses_exact_target_by_strict_subtype(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.source_type {
    Some(ref_type) => {
      let relation = OiHeapRelationFact::from_heaps(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
      (ref_type.is_non_nullable() || !target_nullable) &&
      relation.strict_concrete_heap_matches_target()
    }
    None => false
  }
}

///|
fn OiRefTestOperandFact::success_only_if_non_null(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  not(nullable) &&
  (
    not(exact) ||
    self.source_has_exact_heap(target) ||
    self.source_has_final_heap(ctx, target) ||
    self.producer_fact.exact_heap(target) ||
    self.producer_fact.has_final_heap(ctx, target)
  ) &&
  (
    self.nullable_matches_target(ctx, target) ||
    self.producer_fact.nullable_matches_target(ctx, target)
  )
}

///|
fn OiRefTestOperandFact::success_only_if_null(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  exact &&
  (
    self.matches_nullable_exact_target_only_as_null(ctx, target, nullable) ||
    self.producer_fact.matches_nullable_exact_target_only_as_null(
      ctx, target, nullable,
    )
  )
}

///|
fn OiRefTestOperandFact::known_success(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  (
    not(exact) &&
    (
      self.non_null_matches_target(ctx, target) ||
      self.producer_fact.non_null_matches_target(ctx, target)
    )
  ) ||
  (
    exact &&
    (
      self.matches_exact_test_target(target, nullable) ||
      self.matches_final_exact_test_target(ctx, target, nullable) ||
      self.producer_fact.matches_exact_test_target(target, nullable) ||
      self.producer_fact.matches_final_exact_test_target(ctx, target, nullable)
    )
  ) ||
  (
    not(exact) &&
    nullable &&
    (
      self.nullable_matches_target(ctx, target) ||
      self.producer_fact.nullable_matches_target(ctx, target)
    )
  )
}

///|
fn OiRefTestOperandFact::known_failure(
  self : OiRefTestOperandFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  self.misses_target(ctx, target) ||
  self.producer_fact.misses_target(ctx, target, nullable) ||
  (
    exact &&
    (
      self.misses_exact_target(target, nullable) ||
      self.misses_exact_target_by_strict_subtype(ctx, target, nullable) ||
      self.producer_fact.misses_exact_target(target, nullable) ||
      self.producer_fact.misses_exact_target_by_strict_subtype(
        ctx, target, nullable,
      )
    )
  ) ||
  (not(nullable) && self.null_or_known_miss_for_non_null_target(ctx, target))
}

///|
priv enum OiRefTestEvaluationKind {
  RefTestUnknown
  RefTestSuccess
  RefTestFailure
  RefTestSuccessOnlyIfNull
  RefTestSuccessOnlyIfNonNull
}

///|
priv struct OiRefTestEvaluationFact {
  kind : OiRefTestEvaluationKind
}

///|
priv struct OiDescriptorRefTestEvaluationFact {
  kind : OiRefTestEvaluationKind
}

///|
priv struct OiDescriptorRefTestMissFact {
  boundary_only : Bool
}

///|
fn OiDescriptorRefTestMissFact::from_operand(
  ctx : HotPassContext,
  operand_fact : OiRefTestOperandFact,
  target : @lib.HeapType,
  nullable : Bool,
) -> OiDescriptorRefTestMissFact? {
  // Binaryen v130 evaluates descriptor tests through the same cast-check table
  // that can prove ordinary `ref.test` misses. Starshine currently validates
  // `ref.test_desc` targets against the operand type before OI runs, so a public
  // disjoint descriptor-test miss fixture is rejected locally. Keep that miss
  // reopening point as an explicit descriptor-test fact rather than hiding it in
  // the descriptor evaluation's `Unknown` fallback.
  ignore(nullable)
  let candidate_miss = match operand_fact.source_type {
    Some(ref_type) =>
      OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_miss_target()
    None => false
  }
  if candidate_miss {
    Some({ boundary_only: true })
  } else {
    None
  }
}

///|
fn OiDescriptorRefTestMissFact::proves_boundary_only(
  self : OiDescriptorRefTestMissFact,
) -> Bool {
  self.boundary_only
}

///|
fn OiDescriptorRefTestEvaluationFact::from_operand(
  ctx : HotPassContext,
  operand_fact : OiRefTestOperandFact,
  target : @lib.HeapType,
  nullable : Bool,
) -> OiDescriptorRefTestEvaluationFact {
  // Binaryen v130 routes `ref.test_desc` through the same ref-test visitor and
  // cast-check result family, but Starshine's custom-descriptor surface only
  // represents the source-backed success / success-if-non-null descriptor match
  // subset today. Keep that descriptor-specific evaluation as its own fact so
  // future descriptor miss, GLB, and bottom-target widening can extend this
  // table without reintroducing an opcode-local proof branch.
  let kind = match
    operand_fact.descriptor_matches_or_subtypes_heap(ctx, target) {
    Some((operand_nullable, _)) =>
      if !nullable && operand_nullable {
        RefTestSuccessOnlyIfNonNull
      } else {
        RefTestSuccess
      }
    None => {
      match
        OiDescriptorRefTestMissFact::from_operand(
          ctx, operand_fact, target, nullable,
        ) {
        Some(fact) => ignore(fact.proves_boundary_only())
        None => ()
      }
      RefTestUnknown
    }
  }
  { kind, }
}

///|
fn OiRefTestEvaluationFact::from_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  test_fact : OiRefTestFact,
) -> OiRefTestEvaluationFact {
  // Binaryen v130 `visitRefTest` asks `GCTypeUtils::evaluateCastCheck` for a
  // source-level result (`Success`, `Failure`, `SuccessOnlyIfNull`,
  // `SuccessOnlyIfNonNull`, or `Unknown`) after looking through fallthrough
  // producers. Keep that classification as a fact so the visitor does not own a
  // scanner-like boolean cascade for null, exact, final, descriptor, and
  // fallthrough test cases.
  let nullable = test_fact.nullable
  let exact = test_fact.exact
  let target = test_fact.target
  let operand_fact = OiRefTestOperandFact::from_node(
    ctx,
    func,
    test_fact.operand_id,
  )
  if operand_fact.is_known_null() {
    return {
      kind: if test_fact.known_null_result() == @lib.I32(1) {
        RefTestSuccess
      } else {
        RefTestFailure
      },
    }
  }
  if test_fact.descriptor_style {
    return {
      kind: OiDescriptorRefTestEvaluationFact::from_operand(
        ctx, operand_fact, target, nullable,
      ).kind,
    }
  }
  if operand_fact.success_only_if_non_null(ctx, target, nullable, exact) {
    return { kind: RefTestSuccessOnlyIfNonNull }
  }
  if operand_fact.success_only_if_null(ctx, target, nullable, exact) {
    return { kind: RefTestSuccessOnlyIfNull }
  }
  if operand_fact.known_success(ctx, target, nullable, exact) {
    return { kind: RefTestSuccess }
  }
  if operand_fact.known_failure(ctx, target, nullable, exact) {
    return { kind: RefTestFailure }
  }
  { kind: RefTestUnknown }
}

///|
priv struct OiRefTestResultFact {
  known_const_result : @lib.I32?
  rewrite_to_ref_is_non_null : Bool
  rewrite_to_ref_is_null : Bool
}

///|
fn OiRefTestResultFact::from_evaluation(
  evaluation : OiRefTestEvaluationFact,
) -> OiRefTestResultFact {
  match evaluation.kind {
    RefTestSuccess =>
      {
        known_const_result: Some(@lib.I32(1)),
        rewrite_to_ref_is_non_null: false,
        rewrite_to_ref_is_null: false,
      }
    RefTestFailure =>
      {
        known_const_result: Some(@lib.I32(0)),
        rewrite_to_ref_is_non_null: false,
        rewrite_to_ref_is_null: false,
      }
    RefTestSuccessOnlyIfNull =>
      {
        known_const_result: None,
        rewrite_to_ref_is_non_null: false,
        rewrite_to_ref_is_null: true,
      }
    RefTestSuccessOnlyIfNonNull =>
      {
        known_const_result: None,
        rewrite_to_ref_is_non_null: true,
        rewrite_to_ref_is_null: false,
      }
    RefTestUnknown =>
      {
        known_const_result: None,
        rewrite_to_ref_is_non_null: false,
        rewrite_to_ref_is_null: false,
      }
  }
}

///|
fn OiRefTestResultFact::from_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  test_fact : OiRefTestFact,
) -> OiRefTestResultFact {
  let evaluation = OiRefTestEvaluationFact::from_test(ctx, func, test_fact)
  OiRefTestResultFact::from_evaluation(evaluation)
}

///|
priv enum OiRefTestRewritePlanKind {
  RefTestTightenTarget
  RefTestRewriteToNonNullCheck
  RefTestRewriteToNullCheck
  RefTestRewriteToConst
  RefTestDropOperandThenConst
}

///|
priv struct OiRefTestRewritePlanFact {
  kind : OiRefTestRewritePlanKind
  test_fact : OiRefTestFact
  const_result : @lib.I32?
  narrowed_ref_type : @lib.RefType?
}

///|
fn OiRefTestRewritePlanFact::from_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  test_fact : OiRefTestFact,
) -> OiRefTestRewritePlanFact? {
  // Binaryen v130 `visitRefTest` turns the source-level cast-check result into
  // either a null predicate rewrite or an i32 constant while preserving operand
  // effects when the operand cannot be erased. Keep the replacement decision as
  // a plan fact rather than a visitor-local cascade over evaluation outcomes and
  // purity predicates.
  let (active_test_fact, pending_tightening) = match
    OiRefTestTighteningFact::from_test(ctx, func, test_fact) {
    Some(tightening_fact) => {
      let narrowed_ref_type = tightening_fact.narrowed_ref_type
      (
        {
          nullable: narrowed_ref_type.is_nullable(),
          exact: narrowed_ref_type.is_exact(),
          target: narrowed_ref_type.get_heap_type(),
          operand_id: test_fact.operand_id,
          descriptor_style: test_fact.descriptor_style,
        },
        Some(narrowed_ref_type),
      )
    }
    None => (test_fact, None)
  }
  let result_fact = OiRefTestResultFact::from_test(ctx, func, active_test_fact)
  if result_fact.rewrite_to_ref_is_non_null {
    return Some({
      kind: RefTestRewriteToNonNullCheck,
      test_fact: active_test_fact,
      const_result: None,
      narrowed_ref_type: None,
    })
  }
  if result_fact.rewrite_to_ref_is_null {
    return Some({
      kind: RefTestRewriteToNullCheck,
      test_fact: active_test_fact,
      const_result: None,
      narrowed_ref_type: None,
    })
  }
  match result_fact.known_const_result {
    Some(value) => {
      let operand_id = test_fact.operand_id
      let can_erase_operand = (
          value == @lib.I32(0) &&
          (
            OiTriviallyPureOperandFact::proves_node_pure(func, operand_id) ||
            optimize_instructions_node_effects_are_pure(ctx, func, operand_id)
          )
        ) ||
        (
          value != @lib.I32(0) &&
          optimize_instructions_node_effects_are_pure(ctx, func, operand_id)
        )
      Some({
        kind: if can_erase_operand {
          RefTestRewriteToConst
        } else {
          RefTestDropOperandThenConst
        },
        test_fact: active_test_fact,
        const_result: Some(value),
        narrowed_ref_type: None,
      })
    }
    None =>
      match pending_tightening {
        Some(narrowed_ref_type) =>
          Some({
            kind: RefTestTightenTarget,
            test_fact: active_test_fact,
            const_result: None,
            narrowed_ref_type: Some(narrowed_ref_type),
          })
        None => None
      }
  }
}

///|
fn OiRefTestRewritePlanFact::replace_with_ref_is_null(
  self : OiRefTestRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  OiRefIsNullRewritePlanFact::replace_node_with_ref_is_null(
    ctx,
    func,
    node_id,
    self.test_fact.operand_id,
  )
}

///|
fn OiRefTestRewritePlanFact::replace_with_ref_is_non_null_test(
  self : OiRefTestRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let operand_id = self.test_fact.operand_id
  let is_null = @ir.hot_build_unary(func, @lib.ValType::i32(), operand_id)
  @ir.hot_node_exact_instr_set(func, is_null, @lib.Instruction::ref_is_null())
  let non_null = @ir.hot_build_unary(func, @lib.ValType::i32(), is_null)
  @ir.hot_node_exact_instr_set(func, non_null, @lib.Instruction::i32_eqz())
  let replacement = @ir.hot_node_get(func, non_null)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_delete_node(func, non_null)
  pass_mark_mutated(ctx, func)
}

///|
fn OiRefTestRewritePlanFact::apply(
  self : OiRefTestRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let operand_id = self.test_fact.operand_id
  match self.kind {
    RefTestTightenTarget => {
      let narrowed_ref_type = match self.narrowed_ref_type {
        Some(ref_type) => ref_type
        None => return false
      }
      let payload_id = @ir.hot_alloc_instr_payload(
        func,
        @ir.HotInstrPayload::new(
          @lib.Instruction::ref_test_type(narrowed_ref_type),
        ),
      )
      let narrowed = @ir.hot_build_node(
        func,
        @ir.hot_node_get(func, node_id).op,
        @ir.hot_type_intern_value(func, @lib.ValType::i32()),
        imm1=payload_id,
        children=[operand_id],
      )
      @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, narrowed))
      @ir.hot_delete_node(func, narrowed)
      pass_mark_mutated(ctx, func)
      true
    }
    RefTestRewriteToNonNullCheck => {
      self.replace_with_ref_is_non_null_test(ctx, func, node_id)
      true
    }
    RefTestRewriteToNullCheck => {
      self.replace_with_ref_is_null(ctx, func, node_id)
      true
    }
    RefTestRewriteToConst =>
      match self.const_result {
        Some(value) => {
          optimize_instructions_replace_with_const_i32(
            ctx, func, node_id, value,
          )
          true
        }
        None => false
      }
    RefTestDropOperandThenConst =>
      match self.const_result {
        Some(value) => {
          optimize_instructions_replace_with_drop_then_const_i32(
            ctx, func, node_id, operand_id, value,
          )
          true
        }
        None => false
      }
  }
}

///|
priv struct OiRefCastFact {
  nullable : Bool
  exact : Bool
  target : @lib.HeapType
  operand_id : Int
}

///|
fn OiRefCastFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefCastFact? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  let (nullable, exact, target) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefCast(nullable, exact, target)) =>
      (nullable, exact, target)
    _ => return None
  }
  Some({
    nullable,
    exact,
    target,
    operand_id: @ir.hot_child_get(func, node_id, 0),
  })
}

///|
priv struct OiRefCastOperandTargetFact {
  node_op : @ir.HotOp
  source_type : @lib.RefType?
  local_ref_type : @lib.RefType?
  literal_fact : OiRefLiteralFact
}

///|
fn OiRefCastOperandTargetFact::from_operand(
  func : @ir.HotFunc,
  operand_id : Int,
) -> OiRefCastOperandTargetFact {
  let node = @ir.hot_node_get(func, operand_id)
  let source_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, operand_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => Some(ref_type)
    _ => None
  }
  let local_ref_type = match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) => Some(ref_type)
        _ => None
      }
    _ => None
  }
  {
    node_op: node.op,
    source_type,
    local_ref_type,
    literal_fact: OiRefLiteralFact::from_node(func, operand_id),
  }
}

///|
fn OiRefCastOperandTargetFact::is_direct_null(
  self : OiRefCastOperandTargetFact,
) -> Bool {
  match self.node_op {
    @ir.HotOp::RefNull => true
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::source_is_nullable_exact_heap(
  self : OiRefCastOperandTargetFact,
  target : @lib.HeapType,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_nullable() && ref_type.get_heap_type() == target
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::source_has_exact_heap(
  self : OiRefCastOperandTargetFact,
  target : @lib.HeapType,
) -> Bool {
  match self.source_type {
    Some(ref_type) => ref_type.is_exact() && ref_type.get_heap_type() == target
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::heap_is_known_miss_for_target(
  ctx : HotPassContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  OiHeapRelationFact::from_heaps(ctx, source, target).known_miss_target()
}

///|
fn OiRefCastOperandTargetFact::known_match_target(
  self : OiRefCastOperandTargetFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  if self.literal_fact.matches_target(target) {
    return true
  }
  match self.node_op {
    @ir.HotOp::LocalGet =>
      match self.local_ref_type {
        Some(ref_type) =>
          ref_type.is_non_nullable() &&
          OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_match_without_full_subtyping()
        _ => false
      }
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::known_match_nullable_target(
  self : OiRefCastOperandTargetFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  match self.node_op {
    @ir.HotOp::LocalGet =>
      match self.local_ref_type {
        Some(ref_type) =>
          ref_type.is_nullable() &&
          OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_match_without_full_subtyping()
        _ => false
      }
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::known_miss_target(
  self : OiRefCastOperandTargetFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  if self.literal_fact.i31_cannot_match_target(target) {
    return true
  }
  match self.node_op {
    @ir.HotOp::LocalGet =>
      match self.local_ref_type {
        Some(ref_type) =>
          ref_type.is_non_nullable() &&
          OiRefCastOperandTargetFact::heap_is_known_miss_for_target(
            ctx,
            ref_type.get_heap_type(),
            target,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::null_or_known_miss_for_non_null_target(
  self : OiRefCastOperandTargetFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
) -> Bool {
  match self.node_op {
    @ir.HotOp::LocalGet =>
      match self.local_ref_type {
        Some(ref_type) =>
          OiRefCastOperandTargetFact::heap_is_known_miss_for_target(
            ctx,
            ref_type.get_heap_type(),
            target,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::misses_exact_target(
  self : OiRefCastOperandTargetFact,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_exact() &&
      ref_type.get_heap_type() != target &&
      (ref_type.is_non_nullable() || !target_nullable)
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::misses_exact_target_by_strict_subtype(
  self : OiRefCastOperandTargetFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match self.source_type {
    Some(ref_type) => {
      let relation = OiHeapRelationFact::from_heaps(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
      (ref_type.is_non_nullable() || !target_nullable) &&
      relation.strict_concrete_heap_matches_target()
    }
    _ => false
  }
}

///|
fn OiRefCastOperandTargetFact::matches_nullable_exact_target_only_as_null(
  self : OiRefCastOperandTargetFact,
  ctx : HotPassContext,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  if !target_nullable {
    return false
  }
  match self.source_type {
    Some(ref_type) => {
      let relation = OiHeapRelationFact::from_heaps(
        ctx,
        ref_type.get_heap_type(),
        target,
      )
      relation.concrete_source_matches_nullable_exact_target_only_as_null(
        ref_type.is_nullable(),
        ref_type.is_exact(),
        target_nullable,
      )
    }
    _ => false
  }
}

///|
priv struct OiRefCastOperandFact {
  direct_null_operand : Bool
  nullable_exact_target_type : Bool
  has_exact_target_heap : Bool
  known_match_target : Bool
  known_match_nullable_target : Bool
  known_miss_target : Bool
  null_or_known_miss_for_non_null_target : Bool
  misses_exact_target : Bool
  misses_exact_target_by_strict_subtype : Bool
  matches_nullable_exact_target_only_as_null : Bool
  can_erase : Bool
}

///|
fn OiRefCastOperandFact::from_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  operand_id : Int,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> OiRefCastOperandFact {
  // Binaryen v130 `visitRefCast` centralizes cast-check knowledge in
  // `GCTypeUtils::evaluateCastCheck` and then separately asks whether operand
  // effects must be preserved before trapping. Keep Starshine's represented
  // operand/target relation as one fact so ref.cast and descriptor exact-miss
  // plans do not own parallel helper-level predicate cascades.
  let target_fact = OiRefCastOperandTargetFact::from_operand(func, operand_id)
  let trivially_pure = OiTriviallyPureOperandFact::proves_node_pure(
    func, operand_id,
  )
  let effects_pure = optimize_instructions_node_effects_are_pure(
    ctx, func, operand_id,
  )
  {
    direct_null_operand: target_fact.is_direct_null(),
    nullable_exact_target_type: target_fact.source_is_nullable_exact_heap(
      target,
    ),
    has_exact_target_heap: target_fact.source_has_exact_heap(target),
    known_match_target: target_fact.known_match_target(ctx, target),
    known_match_nullable_target: target_fact.known_match_nullable_target(
      ctx, target,
    ),
    known_miss_target: target_fact.known_miss_target(ctx, target),
    null_or_known_miss_for_non_null_target: target_fact.null_or_known_miss_for_non_null_target(
      ctx, target,
    ),
    misses_exact_target: target_fact.misses_exact_target(
      target, target_nullable,
    ),
    misses_exact_target_by_strict_subtype: target_fact.misses_exact_target_by_strict_subtype(
      ctx, target, target_nullable,
    ),
    matches_nullable_exact_target_only_as_null: target_fact.matches_nullable_exact_target_only_as_null(
      ctx, target, target_nullable,
    ),
    can_erase: trivially_pure || effects_pure,
  }
}

///|
fn OiRefCastOperandFact::can_rewrite_as_non_null(
  self : OiRefCastOperandFact,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  !nullable &&
  (!exact || self.has_exact_target_heap) &&
  self.nullable_exact_target_type
}

///|
fn OiRefCastOperandFact::can_rewrite_nullable_exact_target_only_as_null(
  self : OiRefCastOperandFact,
  exact : Bool,
) -> Bool {
  exact && self.matches_nullable_exact_target_only_as_null
}

///|
fn OiRefCastOperandFact::can_forward_operand(
  self : OiRefCastOperandFact,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  (!exact || self.has_exact_target_heap) &&
  (self.known_match_target || (nullable && self.known_match_nullable_target))
}

///|
fn OiRefCastOperandFact::can_prove_trap(
  self : OiRefCastOperandFact,
  nullable : Bool,
  exact : Bool,
) -> Bool {
  self.known_miss_target ||
  (
    exact &&
    (self.misses_exact_target || self.misses_exact_target_by_strict_subtype)
  ) ||
  (!nullable && self.null_or_known_miss_for_non_null_target)
}

///|
priv struct OiRefCastTighteningFact {
  narrowed_ref_type : @lib.RefType
}

///|
priv struct OiRefCastChildCastFact {
  replacement_operand_id : Int
}

///|
priv struct OiRefCastChildNonNullFact {
  replacement_operand_id : Int
  narrowed_ref_type : @lib.RefType
}

///|
fn OiRefCastTighteningFact::from_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_fact : OiRefCastFact,
) -> OiRefCastTighteningFact? {
  // Binaryen v130 `visitRefCast` first intersects ordinary cast result type
  // with `getFallthroughType(ref)` using `Type::getGreatestLowerBound`, then
  // re-optimizes the cast before known-result and child-wrapper folds. Keep the
  // represented GLB/nullability rule as a fact over the cast target and operand
  // fallthrough type instead of another visitor-local ref-type scanner.
  let current_ref_type = @lib.RefType::new(
    cast_fact.nullable,
    cast_fact.target,
    exact=cast_fact.exact,
  )
  let fallthrough_ref_type = match
    OiRefFallthroughFact::from_node(ctx, func, cast_fact.operand_id).ref_type {
    Some(ref_type) => ref_type
    None => return None
  }
  match
    optimize_instructions_ref_fallthrough_lower_bound(
      ctx, current_ref_type, fallthrough_ref_type,
    ) {
    Some(narrowed_ref_type) if narrowed_ref_type != current_ref_type =>
      Some({ narrowed_ref_type, })
    _ => None
  }
}

///|
fn OiRefCastChildCastFact::ref_type_is_subtype(
  ctx : HotPassContext,
  source : @lib.RefType,
  target : @lib.RefType,
) -> Bool {
  let nullable_ok = target.is_nullable() || source.is_non_nullable()
  if !nullable_ok {
    return false
  }
  if target.is_exact() {
    return source.is_exact() && source.get_heap_type() == target.get_heap_type()
  }
  OiHeapRelationFact::from_heaps(
    ctx,
    source.get_heap_type(),
    target.get_heap_type(),
  ).known_match_target()
}

///|
fn OiRefCastChildCastFact::from_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_fact : OiRefCastFact,
) -> OiRefCastChildCastFact? {
  // Binaryen v130 `visitRefCast` removes an ordinary child `RefCast` after all
  // known-result folds when the parent cast is at least as strong as the child
  // cast (`Type::isSubType(curr->type, child->type)`). Keep that source rule as
  // a fact over current/child ref types instead of a rewrite-local opcode scan;
  // descriptor child casts remain excluded until Starshine has the child
  // localization needed to drop/reorder their descriptor operands.
  let child_id = cast_fact.operand_id
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return None
  }
  match @ir.hot_node_get(func, child_id).op {
    @ir.HotOp::RefCast => ()
    _ => return None
  }
  let child_fact = match OiRefCastFact::from_node(func, child_id) {
    Some(fact) => fact
    None => return None
  }
  let parent_type = @lib.RefType::new(
    cast_fact.nullable,
    cast_fact.target,
    exact=cast_fact.exact,
  )
  let child_type = @lib.RefType::new(
    child_fact.nullable,
    child_fact.target,
    exact=child_fact.exact,
  )
  if OiRefCastChildCastFact::ref_type_is_subtype(ctx, parent_type, child_type) {
    Some({ replacement_operand_id: child_fact.operand_id })
  } else {
    None
  }
}

///|
fn OiRefCastChildNonNullFact::from_cast(
  func : @ir.HotFunc,
  cast_fact : OiRefCastFact,
) -> OiRefCastChildNonNullFact? {
  // Binaryen v130 `visitRefCast` removes an ordinary child `ref.as_non_null`
  // after known-result and child-cast folds by retyping the parent cast as
  // non-null and rewiring it to the `ref.as_non_null` operand. Keep the child
  // wrapper classification, replacement operand, and narrowed target type in a
  // fact so the ref.cast plan does not own another opcode-local scanner.
  let child_id = cast_fact.operand_id
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return None
  }
  match @ir.hot_node_get(func, child_id).op {
    @ir.HotOp::Heap => ()
    _ => return None
  }
  match @ir.hot_node_exact_instr(func, child_id) {
    Some(@lib.Instruction::RefAsNonNull) => ()
    _ => return None
  }
  if @ir.hot_child_count(func, child_id) != 1 {
    return None
  }
  Some({
    replacement_operand_id: @ir.hot_child_get(func, child_id, 0),
    narrowed_ref_type: @lib.RefType::new(
      false,
      cast_fact.target,
      exact=cast_fact.exact,
    ),
  })
}

///|
priv enum OiRefCastRewritePlanKind {
  RefCastTightenTarget
  RefCastForwardOperand
  RefCastUnreachable
  RefCastDropOperandThenUnreachable
  RefCastAsNonNull
  RefCastNullrefCast
  RefCastSkipChildCast
  RefCastSkipChildNonNull
}

///|
priv struct OiRefCastRewritePlanFact {
  kind : OiRefCastRewritePlanKind
  cast_fact : OiRefCastFact
  replacement_operand_id : Int
  narrowed_ref_type : @lib.RefType?
}

///|
fn OiRefCastRewritePlanFact::from_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_fact : OiRefCastFact,
) -> OiRefCastRewritePlanFact? {
  // Binaryen v130 `visitRefCast` first tightens ordinary cast type with
  // fallthrough/GLB information, then routes source-level cast outcomes through
  // `GCTypeUtils::evaluateCastCheck` and chooses whether to forward the operand,
  // keep only a null check, materialize null, or trap. Keep the represented
  // Starshine subset as a plan fact fed by cast/fallthrough and operand facts so
  // the visitor does not own a scanner-like cascade of local/ref/null/exactness
  // predicates. When a tightening fact unlocks an existing known-result or child
  // rewrite, use the tightened cast fact immediately; Binaryen reaches the same
  // state by replacing and re-optimizing the cast.
  let (active_cast_fact, pending_tightening) = match
    OiRefCastTighteningFact::from_cast(ctx, func, cast_fact) {
    Some(tightening_fact) => {
      let narrowed_ref_type = tightening_fact.narrowed_ref_type
      (
        {
          nullable: narrowed_ref_type.is_nullable(),
          exact: narrowed_ref_type.is_exact(),
          target: narrowed_ref_type.get_heap_type(),
          operand_id: cast_fact.operand_id,
        },
        Some(narrowed_ref_type),
      )
    }
    None => (cast_fact, None)
  }
  let nullable = active_cast_fact.nullable
  let exact = active_cast_fact.exact
  let operand_fact = OiRefCastOperandFact::from_operand(
    ctx,
    func,
    active_cast_fact.operand_id,
    active_cast_fact.target,
    nullable,
  )
  if operand_fact.direct_null_operand {
    return Some({
      kind: if nullable {
        RefCastForwardOperand
      } else {
        RefCastUnreachable
      },
      cast_fact: active_cast_fact,
      replacement_operand_id: -1,
      narrowed_ref_type: None,
    })
  }
  if operand_fact.can_rewrite_as_non_null(nullable, exact) {
    return Some({
      kind: RefCastAsNonNull,
      cast_fact: active_cast_fact,
      replacement_operand_id: -1,
      narrowed_ref_type: None,
    })
  }
  if operand_fact.can_rewrite_nullable_exact_target_only_as_null(exact) {
    return Some({
      kind: RefCastNullrefCast,
      cast_fact: active_cast_fact,
      replacement_operand_id: -1,
      narrowed_ref_type: None,
    })
  }
  if operand_fact.can_forward_operand(nullable, exact) {
    return Some({
      kind: RefCastForwardOperand,
      cast_fact: active_cast_fact,
      replacement_operand_id: -1,
      narrowed_ref_type: None,
    })
  }
  if operand_fact.can_prove_trap(nullable, exact) {
    let kind = if operand_fact.can_erase {
      RefCastUnreachable
    } else {
      RefCastDropOperandThenUnreachable
    }
    return Some({
      kind,
      cast_fact: active_cast_fact,
      replacement_operand_id: -1,
      narrowed_ref_type: None,
    })
  }
  match OiRefCastChildCastFact::from_cast(ctx, func, active_cast_fact) {
    Some(child_fact) =>
      return Some({
        kind: RefCastSkipChildCast,
        cast_fact: active_cast_fact,
        replacement_operand_id: child_fact.replacement_operand_id,
        narrowed_ref_type: None,
      })
    None => ()
  }
  match OiRefCastChildNonNullFact::from_cast(func, active_cast_fact) {
    Some(child_fact) =>
      return Some({
        kind: RefCastSkipChildNonNull,
        cast_fact: active_cast_fact,
        replacement_operand_id: child_fact.replacement_operand_id,
        narrowed_ref_type: Some(child_fact.narrowed_ref_type),
      })
    None => ()
  }
  match pending_tightening {
    Some(narrowed_ref_type) =>
      Some({
        kind: RefCastTightenTarget,
        cast_fact: active_cast_fact,
        replacement_operand_id: active_cast_fact.operand_id,
        narrowed_ref_type: Some(narrowed_ref_type),
      })
    None => None
  }
}

///|
fn OiRefCastRewritePlanFact::apply(
  self : OiRefCastRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let operand_id = self.cast_fact.operand_id
  match self.kind {
    RefCastTightenTarget => {
      let narrowed_ref_type = match self.narrowed_ref_type {
        Some(ref_type) => ref_type
        None => return false
      }
      let payload_id = @ir.hot_alloc_instr_payload(
        func,
        @ir.HotInstrPayload::new(
          @lib.Instruction::ref_cast_type(narrowed_ref_type),
        ),
      )
      let narrowed = @ir.hot_build_node(
        func,
        @ir.hot_node_get(func, node_id).op,
        @ir.hot_type_intern_value(
          func,
          @lib.ValType::ref_type(narrowed_ref_type),
        ),
        imm1=payload_id,
        children=[self.replacement_operand_id],
      )
      @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, narrowed))
      @ir.hot_delete_node(func, narrowed)
      pass_mark_mutated(ctx, func)
      true
    }
    RefCastForwardOperand => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, operand_id)
      true
    }
    RefCastUnreachable => {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      true
    }
    RefCastDropOperandThenUnreachable =>
      optimize_instructions_replace_with_drop_then_unreachable(
        ctx, func, node_id, operand_id,
      )
    RefCastAsNonNull =>
      optimize_instructions_replace_ref_cast_with_ref_as_non_null(
        ctx, func, node_id, operand_id,
      )
    RefCastNullrefCast =>
      optimize_instructions_replace_ref_cast_with_nullref_cast(
        ctx, func, node_id, operand_id,
      )
    RefCastSkipChildCast => {
      @ir.hot_child_set(func, node_id, 0, self.replacement_operand_id)
      pass_mark_mutated(ctx, func)
      true
    }
    RefCastSkipChildNonNull => {
      let narrowed_ref_type = match self.narrowed_ref_type {
        Some(ref_type) => ref_type
        None => return false
      }
      let payload_id = @ir.hot_alloc_instr_payload(
        func,
        @ir.HotInstrPayload::new(
          @lib.Instruction::ref_cast_type(narrowed_ref_type),
        ),
      )
      let narrowed = @ir.hot_build_node(
        func,
        @ir.hot_node_get(func, node_id).op,
        @ir.hot_type_intern_value(
          func,
          @lib.ValType::ref_type(narrowed_ref_type),
        ),
        imm1=payload_id,
        children=[self.replacement_operand_id],
      )
      @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, narrowed))
      @ir.hot_delete_node(func, narrowed)
      pass_mark_mutated(ctx, func)
      true
    }
  }
}

///|
priv struct OiDescriptorCastFact {
  node_id : Int
  nullable : Bool
  exact : Bool
  target : @lib.HeapType
  operand_id : Int
  descriptor_id : Int
}

///|
fn OiDescriptorCastFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorCastFact? {
  if @ir.hot_child_count(func, node_id) != 2 {
    return None
  }
  let (nullable, exact, target) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefCastDescEq(nullable, exact, target)) =>
      (nullable, exact, target)
    _ => return None
  }
  Some({
    node_id,
    nullable,
    exact,
    target,
    operand_id: @ir.hot_child_get(func, node_id, 0),
    descriptor_id: @ir.hot_child_get(func, node_id, 1),
  })
}

///|
priv struct OiDescriptorCastTighteningFact {
  cast_fact : OiDescriptorCastFact
  operand_fallthrough_non_null : Bool
  narrowed_ref_type : @lib.RefType
}

///|
fn OiDescriptorCastTighteningFact::from_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_fact : OiDescriptorCastFact,
) -> OiDescriptorCastTighteningFact? {
  // Binaryen v130 `visitRefCast` tightens descriptor-cast nullability before
  // known-result cleanup: descriptor casts cannot change their heap target from
  // the reference operand because the descriptor child controls that, but a
  // non-null fallthrough reference makes every successful result non-null. Keep
  // this separate from descriptor success/exactness facts because it does not
  // require proving that the operand heap already matches or subtypes the target.
  if !cast_fact.nullable {
    return None
  }
  let operand_fallthrough_non_null = match
    OiRefFallthroughFact::from_node(ctx, func, cast_fact.operand_id).ref_type {
    Some(ref_type) => ref_type.is_non_nullable()
    None => false
  }
  if !operand_fallthrough_non_null {
    return None
  }
  Some({
    cast_fact,
    operand_fallthrough_non_null,
    narrowed_ref_type: @lib.RefType::new(
      false,
      cast_fact.target,
      exact=cast_fact.exact,
    ),
  })
}

///|
priv struct OiDescriptorCastTighteningRewritePlanFact {
  tightening_fact : OiDescriptorCastTighteningFact
}

///|
fn OiDescriptorCastTighteningRewritePlanFact::from_fact(
  tightening_fact : OiDescriptorCastTighteningFact,
) -> OiDescriptorCastTighteningRewritePlanFact? {
  if !tightening_fact.operand_fallthrough_non_null {
    return None
  }
  Some({ tightening_fact, })
}

///|
fn OiDescriptorCastTighteningRewritePlanFact::apply(
  self : OiDescriptorCastTighteningRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cast_fact = self.tightening_fact.cast_fact
  let narrowed_ref_type = self.tightening_fact.narrowed_ref_type
  let payload_id = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(
      @lib.Instruction::ref_cast_desc_eq_type(narrowed_ref_type),
    ),
  )
  let narrowed = @ir.hot_build_node(
    func,
    @ir.hot_node_get(func, cast_fact.node_id).op,
    @ir.hot_type_intern_value(func, @lib.ValType::ref_type(narrowed_ref_type)),
    imm1=payload_id,
    children=[cast_fact.operand_id, cast_fact.descriptor_id],
  )
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, narrowed))
  @ir.hot_delete_node(func, narrowed)
  pass_mark_mutated(ctx, func)
  true
}

///|
priv struct OiDescriptorExactMissDropBeforeUnreachableFact {
  live : Bool
  control_or_exit_root : Bool
  all_children_straight_line : Bool
  straight_line : Bool
  direct_call_root : Bool
  block_region_straight_line : Bool
  block_can_drop_before_unreachable : Bool
  call_can_drop_before_unreachable : Bool
}

///|
fn OiDescriptorExactMissDropBeforeUnreachableFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorExactMissDropBeforeUnreachableFact {
  // Binaryen v130 lowers statically-impossible descriptor equality casts with
  // `getDroppedChildrenAndAppend(..., unreachable, IgnoreParentEffects)`. Keep
  // Starshine's represented source-order preservation subset as an explicit
  // fact: a subtree may be dropped before the replacement trap only when every
  // evaluated expression is straight-line, and only block/direct-call roots are
  // currently materialized by the exact-miss rewrite plans.
  let node = @ir.hot_node_get(func, node_id)
  let control_or_exit_root = match node.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef => true
    _ => false
  }
  let mut all_children_straight_line = true
  if !control_or_exit_root {
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      if !OiDescriptorExactMissDropBeforeUnreachableFact::from_node(
          func,
          @ir.hot_child_get(func, node_id, slot),
        ).straight_line {
        all_children_straight_line = false
      }
    }
  }
  let straight_line = !control_or_exit_root && all_children_straight_line
  let direct_call_root = match node.op {
    @ir.HotOp::Call => true
    _ => false
  }
  let mut block_region_straight_line = false
  match node.op {
    @ir.HotOp::Block => {
      block_region_straight_line = true
      let body = @ir.hot_region_body_ref(func, node_id)
      for slot = 0
          slot < @ir.hot_region_root_count(func, body)
          slot = slot + 1 {
        if !OiDescriptorExactMissDropBeforeUnreachableFact::from_node(
            func,
            @ir.hot_region_get(func, body, slot),
          ).straight_line {
          block_region_straight_line = false
        }
      }
    }
    _ => ()
  }
  {
    live: true,
    control_or_exit_root,
    all_children_straight_line,
    straight_line,
    direct_call_root,
    block_region_straight_line,
    block_can_drop_before_unreachable: block_region_straight_line,
    call_can_drop_before_unreachable: direct_call_root && straight_line,
  }
}

///|
priv struct OiDescriptorExactMissFact {
  cast_fact : OiDescriptorCastFact
  descriptor_exactly_describes_target : Bool
  ref_operand_misses_target : Bool
  descriptor_can_erase : Bool
  ref_operand_can_erase : Bool
  ref_operand_can_drop_before_unreachable : Bool
  descriptor_can_drop_before_unreachable : Bool
  descriptor_call_can_drop_before_unreachable : Bool
}

///|
fn OiDescriptorExactMissFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorExactMissFact? {
  let cast_fact = match OiDescriptorCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let operand_drop_fact = OiDescriptorExactMissDropBeforeUnreachableFact::from_node(
    func,
    cast_fact.operand_id,
  )
  let descriptor_drop_fact = OiDescriptorExactMissDropBeforeUnreachableFact::from_node(
    func,
    cast_fact.descriptor_id,
  )
  let ref_operand_fact = OiRefCastOperandFact::from_operand(
    ctx,
    func,
    cast_fact.operand_id,
    cast_fact.target,
    cast_fact.nullable,
  )
  Some({
    cast_fact,
    descriptor_exactly_describes_target: OiDescriptorTypeFact::from_node(
      ctx,
      func,
      cast_fact.descriptor_id,
    ).exactly_describes(cast_fact.target),
    ref_operand_misses_target: ref_operand_fact.misses_exact_target ||
    ref_operand_fact.misses_exact_target_by_strict_subtype,
    descriptor_can_erase: OiDescriptorOperandEraseFact::from_operand(
      ctx,
      func,
      dead,
      cast_fact.descriptor_id,
    ).proves_can_erase(),
    ref_operand_can_erase: ref_operand_fact.can_erase,
    ref_operand_can_drop_before_unreachable: operand_drop_fact.live &&
    (
      (
        operand_drop_fact.block_can_drop_before_unreachable &&
        operand_drop_fact.control_or_exit_root &&
        operand_drop_fact.block_region_straight_line
      ) ||
      (
        operand_drop_fact.call_can_drop_before_unreachable &&
        !operand_drop_fact.control_or_exit_root &&
        operand_drop_fact.direct_call_root &&
        operand_drop_fact.all_children_straight_line
      )
    ),
    descriptor_can_drop_before_unreachable: descriptor_drop_fact.live &&
    descriptor_drop_fact.control_or_exit_root &&
    descriptor_drop_fact.block_region_straight_line &&
    descriptor_drop_fact.block_can_drop_before_unreachable,
    descriptor_call_can_drop_before_unreachable: descriptor_drop_fact.live &&
    !descriptor_drop_fact.control_or_exit_root &&
    descriptor_drop_fact.direct_call_root &&
    descriptor_drop_fact.all_children_straight_line &&
    descriptor_drop_fact.call_can_drop_before_unreachable,
  })
}

///|
priv enum OiDescriptorExactMissRewritePlanKind {
  DescriptorExactMissUnreachable
  DescriptorExactMissDropOperandThenUnreachable
  DescriptorExactMissDropDescriptorThenUnreachable
  DescriptorExactMissDropBothThenUnreachable
}

///|
priv struct OiDescriptorExactMissRewritePlanFact {
  kind : OiDescriptorExactMissRewritePlanKind
  miss_fact : OiDescriptorExactMissFact
}

///|
fn OiDescriptorExactMissRewritePlanFact::from_miss(
  ctx : HotPassContext,
  miss_fact : OiDescriptorExactMissFact,
) -> OiDescriptorExactMissRewritePlanFact? {
  // Binaryen v130 `visitRefCast`/descriptor-equality miss cleanup only runs in
  // normal trapping mode. Keep the source-level replacement choice as a plan
  // fact so descriptor casts do not hide a visitor-local drop/unreachable
  // branch cascade.
  if ctx.traps_never_happen || ctx.ignore_implicit_traps {
    return None
  }
  if !miss_fact.descriptor_exactly_describes_target ||
    !miss_fact.ref_operand_misses_target {
    return None
  }
  let kind = if miss_fact.descriptor_can_erase &&
    miss_fact.ref_operand_can_erase {
    DescriptorExactMissUnreachable
  } else if miss_fact.descriptor_can_erase &&
    miss_fact.ref_operand_can_drop_before_unreachable {
    DescriptorExactMissDropOperandThenUnreachable
  } else if miss_fact.ref_operand_can_erase &&
    (
      miss_fact.descriptor_can_drop_before_unreachable ||
      miss_fact.descriptor_call_can_drop_before_unreachable
    ) {
    DescriptorExactMissDropDescriptorThenUnreachable
  } else if miss_fact.ref_operand_can_drop_before_unreachable &&
    (
      miss_fact.descriptor_can_drop_before_unreachable ||
      miss_fact.descriptor_call_can_drop_before_unreachable
    ) {
    DescriptorExactMissDropBothThenUnreachable
  } else {
    return None
  }
  Some({ kind, miss_fact })
}

///|
fn OiDescriptorExactMissRewritePlanFact::apply(
  self : OiDescriptorExactMissRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cast_fact = self.miss_fact.cast_fact
  match self.kind {
    DescriptorExactMissUnreachable => {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      true
    }
    DescriptorExactMissDropOperandThenUnreachable =>
      optimize_instructions_replace_with_drop_then_unreachable(
        ctx,
        func,
        node_id,
        cast_fact.operand_id,
      )
    DescriptorExactMissDropDescriptorThenUnreachable =>
      optimize_instructions_replace_with_drop_then_unreachable(
        ctx,
        func,
        node_id,
        cast_fact.descriptor_id,
      )
    DescriptorExactMissDropBothThenUnreachable =>
      optimize_instructions_replace_with_drop_drop_then_unreachable(
        ctx,
        func,
        node_id,
        cast_fact.operand_id,
        cast_fact.descriptor_id,
      )
  }
}

///|
priv struct OiDescriptorTnhSkipFact {
  cast_fact : OiDescriptorCastFact
  descriptor_fact : OiDescriptorOperandFact
  operand_matches_target : Bool
  operand_nullable : Bool
  operand_exact : Bool
}

///|
fn OiDescriptorTnhSkipFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorTnhSkipFact? {
  let cast_fact = match OiDescriptorCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let (operand_matches_target, operand_nullable, operand_exact) = match
    OiRefProducerFact::from_node(ctx, func, cast_fact.operand_id).matches_or_subtypes_heap(
      ctx,
      cast_fact.target,
    ) {
    Some((nullable, exact)) => (true, nullable, exact)
    None => (false, false, false)
  }
  Some({
    cast_fact,
    descriptor_fact: OiDescriptorOperandFact::from_operand(
      ctx,
      func,
      dead,
      cast_fact.descriptor_id,
    ),
    operand_matches_target,
    operand_nullable,
    operand_exact,
  })
}

///|
fn OiDescriptorTnhSkipFact::can_skip(
  self : OiDescriptorTnhSkipFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  if !ctx.traps_never_happen || !self.operand_matches_target {
    return false
  }
  let cast_fact = self.cast_fact
  if (!cast_fact.nullable && self.operand_nullable) ||
    (cast_fact.exact && !self.operand_exact) {
    return false
  }
  match self.descriptor_fact.type_fact.exact_described_heap {
    Some(described_heap) =>
      if OiHeapRelationFact::from_heaps(ctx, described_heap, cast_fact.target).known_subtype &&
        !OiRefProducerFact::from_node(ctx, func, cast_fact.operand_id).exact_heap(
          described_heap,
        ) &&
        !self.descriptor_fact.may_drop_exactness_for_tnh_escaping_ref_get_desc {
        return false
      }
    None => ()
  }
  true
}

///|
priv enum OiDescriptorTnhSkipRewritePlanKind {
  DescriptorTnhSkipForwardOperand
  DescriptorTnhSkipLocalizeOperandThenDescriptor
  DescriptorTnhSkipLocalSetDescriptorThenOperand
  DescriptorTnhSkipDropDescriptorThenOperand
}

///|
priv struct OiDescriptorTnhSkipRewritePlanFact {
  kind : OiDescriptorTnhSkipRewritePlanKind
  skip_fact : OiDescriptorTnhSkipFact
}

///|
fn OiDescriptorTnhSkipRewritePlanFact::from_skip(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  skip_fact : OiDescriptorTnhSkipFact,
) -> OiDescriptorTnhSkipRewritePlanFact? {
  // Binaryen v130 removes descriptor equality casts under TNH only after the
  // reference operand is known to match and the descriptor check can be treated
  // as non-trapping. Preserve the replacement-order decision as a fact: erase
  // the descriptor, localize around ordered effects, localize descriptor-only
  // values, or append a descriptor drop.
  if !skip_fact.can_skip(ctx, func) {
    return None
  }
  let cast_fact = skip_fact.cast_fact
  let descriptor_fact = skip_fact.descriptor_fact
  let kind = if descriptor_fact.can_erase {
    DescriptorTnhSkipForwardOperand
  } else if OiDescriptorSkipOrderFact::from_node(func, cast_fact.operand_id).proves_must_preserve_operand_order() {
    DescriptorTnhSkipLocalizeOperandThenDescriptor
  } else if descriptor_fact.should_localize_when_skipped {
    DescriptorTnhSkipLocalSetDescriptorThenOperand
  } else {
    DescriptorTnhSkipDropDescriptorThenOperand
  }
  Some({ kind, skip_fact })
}

///|
fn OiDescriptorTnhSkipRewritePlanFact::apply(
  self : OiDescriptorTnhSkipRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cast_fact = self.skip_fact.cast_fact
  match self.kind {
    DescriptorTnhSkipForwardOperand => {
      optimize_instructions_replace_with_node_id(
        ctx,
        func,
        node_id,
        cast_fact.operand_id,
      )
      true
    }
    _ => {
      ignore(
        optimize_instructions_try_remove_ref_get_desc_child_null_check_traps_never_happen(
          ctx,
          func,
          cast_fact.descriptor_id,
        ) ||
        optimize_instructions_try_move_ref_get_desc_child_null_check(
          ctx,
          func,
          cast_fact.descriptor_id,
        ),
      )
      match self.kind {
        DescriptorTnhSkipLocalizeOperandThenDescriptor =>
          optimize_instructions_replace_with_localized_node_then_descriptor_then_local_get(
            ctx,
            func,
            node_id,
            cast_fact.operand_id,
            cast_fact.descriptor_id,
          )
        DescriptorTnhSkipLocalSetDescriptorThenOperand =>
          optimize_instructions_replace_with_local_set_then_node_id(
            ctx,
            func,
            node_id,
            cast_fact.descriptor_id,
            cast_fact.operand_id,
          )
        DescriptorTnhSkipDropDescriptorThenOperand =>
          optimize_instructions_replace_with_drop_then_node_id(
            ctx,
            func,
            node_id,
            cast_fact.descriptor_id,
            cast_fact.operand_id,
          )
        DescriptorTnhSkipForwardOperand => false
      }
    }
  }
}

///|
priv struct OiDescriptorNullCastFact {
  cast_fact : OiDescriptorCastFact
  descriptor_fact : OiDescriptorOperandFact
}

///|
fn OiDescriptorNullCastFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorNullCastFact? {
  let cast_fact = match OiDescriptorCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  if !OiRefFact::from_node(func, cast_fact.operand_id).is_known_null() {
    return None
  }
  Some({
    cast_fact,
    descriptor_fact: OiDescriptorOperandFact::from_operand(
      ctx,
      func,
      dead,
      cast_fact.descriptor_id,
    ),
  })
}

///|
priv enum OiDescriptorNullCastRewritePlanKind {
  DescriptorNullCastUnreachable
  DescriptorNullCastTypedNull
  DescriptorNullCastDropDescriptorThenTypedNull
  DescriptorNullCastDropDescriptorThenUnreachable
}

///|
priv struct OiDescriptorNullCastRewritePlanFact {
  kind : OiDescriptorNullCastRewritePlanKind
  null_fact : OiDescriptorNullCastFact
}

///|
fn OiDescriptorNullCastRewritePlanFact::from_null_cast(
  null_fact : OiDescriptorNullCastFact,
  descriptor_traps_only : Bool,
) -> OiDescriptorNullCastRewritePlanFact? {
  // Binaryen v130 `optimizeKnownCastResult` has a descriptor-cast special case
  // for known-null reference operands: materialize the typed null for nullable
  // casts, trap for non-nullable casts, and preserve the descriptor operand only
  // when its evaluation cannot be erased. Keep the source-order decision in a
  // plan fact so the visitor no longer owns a null/ref/descriptor erase cascade.
  let cast_fact = null_fact.cast_fact
  let descriptor_fact = null_fact.descriptor_fact
  if descriptor_fact.traps_without_effects {
    return Some({ kind: DescriptorNullCastUnreachable, null_fact })
  }
  if descriptor_traps_only {
    return None
  }
  let kind = if cast_fact.nullable {
    if descriptor_fact.can_erase {
      DescriptorNullCastTypedNull
    } else {
      DescriptorNullCastDropDescriptorThenTypedNull
    }
  } else if descriptor_fact.can_erase {
    DescriptorNullCastUnreachable
  } else {
    DescriptorNullCastDropDescriptorThenUnreachable
  }
  Some({ kind, null_fact })
}

///|
fn OiDescriptorNullCastRewritePlanFact::apply(
  self : OiDescriptorNullCastRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cast_fact = self.null_fact.cast_fact
  match self.kind {
    DescriptorNullCastUnreachable => {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      true
    }
    DescriptorNullCastTypedNull => {
      let typed_null_id = @ir.hot_build_ref_null(
        func,
        @lib.RefType::new(true, cast_fact.target, exact=cast_fact.exact),
      )
      optimize_instructions_replace_with_node_id(
        ctx, func, node_id, typed_null_id,
      )
      true
    }
    DescriptorNullCastDropDescriptorThenTypedNull => {
      let typed_null_id = @ir.hot_build_ref_null(
        func,
        @lib.RefType::new(true, cast_fact.target, exact=cast_fact.exact),
      )
      optimize_instructions_replace_with_drop_then_node_id(
        ctx,
        func,
        node_id,
        cast_fact.descriptor_id,
        typed_null_id,
      )
    }
    DescriptorNullCastDropDescriptorThenUnreachable =>
      optimize_instructions_replace_with_drop_then_unreachable(
        ctx,
        func,
        node_id,
        cast_fact.descriptor_id,
      )
  }
}

///|
priv struct OiDescriptorExactSuccessFact {
  cast_fact : OiDescriptorCastFact
  direct_call_result_exact_non_null_target : Bool
  descriptor_exactly_describes_target : Bool
}

///|
fn OiDescriptorExactSuccessFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorExactSuccessFact? {
  let cast_fact = match OiDescriptorCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let direct_call_result_exact_non_null_target = match
    @ir.hot_node_get(func, cast_fact.operand_id).op {
    @ir.HotOp::Call | @ir.HotOp::CallIndirect | @ir.HotOp::CallRef =>
      OiRefProducerFact::from_node(ctx, func, cast_fact.operand_id).exact_non_null_heap(
        cast_fact.target,
      )
    _ => false
  }
  Some({
    cast_fact,
    direct_call_result_exact_non_null_target,
    descriptor_exactly_describes_target: OiDescriptorTypeFact::from_node(
      ctx,
      func,
      cast_fact.descriptor_id,
    ).exactly_describes(cast_fact.target),
  })
}

///|
fn OiDescriptorExactSuccessFact::can_skip_traps_never_happen(
  self : OiDescriptorExactSuccessFact,
  ctx : HotPassContext,
) -> Bool {
  ctx.traps_never_happen &&
  !self.cast_fact.nullable &&
  self.cast_fact.exact &&
  self.direct_call_result_exact_non_null_target &&
  self.descriptor_exactly_describes_target
}

///|
priv enum OiDescriptorExactSuccessRewritePlanKind {
  DescriptorExactSuccessLocalizeOperandThenDescriptor
}

///|
priv struct OiDescriptorExactSuccessRewritePlanFact {
  kind : OiDescriptorExactSuccessRewritePlanKind
  success_fact : OiDescriptorExactSuccessFact
}

///|
fn OiDescriptorExactSuccessRewritePlanFact::from_success(
  ctx : HotPassContext,
  success_fact : OiDescriptorExactSuccessFact,
) -> OiDescriptorExactSuccessRewritePlanFact? {
  // Binaryen v130 lets descriptor casts be skipped in traps-never-happen mode
  // when the reference value and descriptor are both exact known matches. The
  // represented Starshine subset is intentionally narrower than Binaryen's
  // full `optimizeKnownCastResult`: it requires a direct call-style reference
  // producer and an exact descriptor type fact, then preserves both operand
  // evaluations through the same ChildLocalizer-shaped replacement.
  if !success_fact.can_skip_traps_never_happen(ctx) {
    return None
  }
  Some({
    kind: DescriptorExactSuccessLocalizeOperandThenDescriptor,
    success_fact,
  })
}

///|
fn OiDescriptorExactSuccessRewritePlanFact::apply(
  self : OiDescriptorExactSuccessRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    DescriptorExactSuccessLocalizeOperandThenDescriptor =>
      optimize_instructions_replace_with_localized_node_then_descriptor_then_local_get(
        ctx,
        func,
        node_id,
        self.success_fact.cast_fact.operand_id,
        self.success_fact.cast_fact.descriptor_id,
      )
  }
}

///|
priv struct OiDescriptorResultNarrowingFact {
  cast_fact : OiDescriptorCastFact
  descriptor_no_escaping_branch_control : Bool
  operand_matches_or_subtypes_target : Bool
  operand_nullable : Bool
  descriptor_described_heap : @lib.HeapType?
  descriptor_described_heap_subtypes_target : Bool
  descriptor_exactly_describes_target : Bool
  narrowed_target : @lib.HeapType
  narrowed_nullable : Bool
  narrowed_exact : Bool
}

///|
fn OiDescriptorResultNarrowingFact::from_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_fact : OiDescriptorCastFact,
  force_non_null : Bool,
) -> OiDescriptorResultNarrowingFact {
  // Binaryen v130's descriptor equality cast result tightening derives from
  // source type facts: the reference operand must match or subtype the target
  // for ordinary result narrowing, the descriptor operand may prove a narrower
  // described heap, and descriptor subtrees with escaping branch control stay
  // fail-closed. Store those decisions in one fact so `visitRefCast` and the
  // surrounding ref.as_non_null movement do not duplicate helper-local scans.
  let descriptor_no_escaping_branch_control = !OiDescriptorBranchControlFact::from_node(
    func,
    cast_fact.descriptor_id,
    cast_fact.descriptor_id,
  ).proves_has_escaping_branch_control()
  let (operand_matches_or_subtypes_target, operand_nullable) = match
    OiRefProducerFact::from_node(ctx, func, cast_fact.operand_id).matches_or_subtypes_heap(
      ctx,
      cast_fact.target,
    ) {
    Some((nullable, _)) => (true, nullable)
    None => (false, false)
  }
  let descriptor_type_fact = OiDescriptorTypeFact::from_node(
    ctx,
    func,
    cast_fact.descriptor_id,
  )
  let descriptor_described_heap = descriptor_type_fact.exact_described_heap
  let descriptor_described_heap_subtypes_target = match
    descriptor_described_heap {
    Some(described_heap) =>
      OiHeapRelationFact::from_heaps(ctx, described_heap, cast_fact.target).known_subtype
    None => false
  }
  let narrowed_target = match descriptor_described_heap {
    Some(described_heap) if descriptor_described_heap_subtypes_target =>
      described_heap
    _ => cast_fact.target
  }
  let descriptor_exactly_describes_target = descriptor_type_fact.exactly_describes(
    cast_fact.target,
  )
  let descriptor_exact = narrowed_target != cast_fact.target ||
    descriptor_exactly_describes_target
  {
    cast_fact,
    descriptor_no_escaping_branch_control,
    operand_matches_or_subtypes_target,
    operand_nullable,
    descriptor_described_heap,
    descriptor_described_heap_subtypes_target,
    descriptor_exactly_describes_target,
    narrowed_target,
    narrowed_nullable: if force_non_null {
      false
    } else {
      cast_fact.nullable && operand_nullable
    },
    narrowed_exact: cast_fact.exact || descriptor_exact,
  }
}

///|
fn OiDescriptorResultNarrowingFact::changes_result_type(
  self : OiDescriptorResultNarrowingFact,
) -> Bool {
  self.narrowed_nullable != self.cast_fact.nullable ||
  self.narrowed_exact != self.cast_fact.exact ||
  self.narrowed_target != self.cast_fact.target
}

///|
fn OiDescriptorResultNarrowingFact::proves_can_narrow_result_type(
  self : OiDescriptorResultNarrowingFact,
) -> Bool {
  ignore(self.descriptor_described_heap)
  ignore(self.descriptor_described_heap_subtypes_target)
  ignore(self.descriptor_exactly_describes_target)
  self.descriptor_no_escaping_branch_control &&
  self.operand_matches_or_subtypes_target &&
  self.changes_result_type()
}

///|
fn OiDescriptorResultNarrowingFact::proves_can_move_ref_as_non_null_into_cast(
  self : OiDescriptorResultNarrowingFact,
) -> Bool {
  ignore(self.operand_matches_or_subtypes_target)
  ignore(self.operand_nullable)
  self.cast_fact.nullable && self.descriptor_no_escaping_branch_control
}

///|
priv enum OiDescriptorResultNarrowingRewriteKind {
  DescriptorResultNarrowCastRoot
  DescriptorResultNarrowRefAsNonNullRoot
}

///|
priv struct OiDescriptorResultNarrowingRewritePlanFact {
  kind : OiDescriptorResultNarrowingRewriteKind
  narrowing_fact : OiDescriptorResultNarrowingFact
}

///|
fn OiDescriptorResultNarrowingRewritePlanFact::from_cast_root(
  narrowing_fact : OiDescriptorResultNarrowingFact,
) -> OiDescriptorResultNarrowingRewritePlanFact? {
  if !narrowing_fact.proves_can_narrow_result_type() {
    return None
  }
  Some({ kind: DescriptorResultNarrowCastRoot, narrowing_fact })
}

///|
fn OiDescriptorResultNarrowingRewritePlanFact::from_ref_as_non_null_root(
  narrowing_fact : OiDescriptorResultNarrowingFact,
) -> OiDescriptorResultNarrowingRewritePlanFact? {
  if !narrowing_fact.proves_can_move_ref_as_non_null_into_cast() {
    return None
  }
  Some({ kind: DescriptorResultNarrowRefAsNonNullRoot, narrowing_fact })
}

///|
fn OiDescriptorResultNarrowingRewritePlanFact::apply(
  self : OiDescriptorResultNarrowingRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    DescriptorResultNarrowCastRoot | DescriptorResultNarrowRefAsNonNullRoot =>
      ()
  }
  let cast_fact = self.narrowing_fact.cast_fact
  let narrowed_ref_type = @lib.RefType::new(
    self.narrowing_fact.narrowed_nullable,
    self.narrowing_fact.narrowed_target,
    exact=self.narrowing_fact.narrowed_exact,
  )
  let narrowed_instr = @lib.Instruction::ref_cast_desc_eq_type(
    narrowed_ref_type,
  )
  let payload_id = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(narrowed_instr),
  )
  let narrowed = @ir.hot_build_node(
    func,
    @ir.hot_node_get(func, cast_fact.node_id).op,
    @ir.hot_type_intern_value(func, @lib.ValType::ref_type(narrowed_ref_type)),
    imm1=payload_id,
    children=[cast_fact.operand_id, cast_fact.descriptor_id],
  )
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, narrowed))
  @ir.hot_delete_node(func, narrowed)
  pass_mark_mutated(ctx, func)
  true
}

///|
priv enum OiDescriptorOperandSimplificationKind {
  DescriptorOperandDirectizeOnly
  DescriptorOperandStripRefAsNonNull
  DescriptorOperandMoveRefGetDescNullCheck
}

///|
priv struct OiDescriptorCallRefDirectizationFact {
  operand_call_ref_id : Int
  descriptor_call_ref_id : Int
}

///|
fn OiDescriptorCallRefDirectizationFact::from_cast_fact(
  func : @ir.HotFunc,
  cast_fact : OiDescriptorCastFact,
) -> OiDescriptorCallRefDirectizationFact? {
  // Binaryen v130 reaches descriptor-cast operands after child visitors have had
  // a chance to run `visitCallRef`; Starshine sometimes needs to request that
  // same child directization while the descriptor-cast plan is active. Keep the
  // operand-slot classification as a fact over the two descriptor-cast children,
  // not as boolean opcode checks embedded in the simplification plan.
  let operand_call_ref_id = match
    @ir.hot_node_get(func, cast_fact.operand_id).op {
    @ir.HotOp::CallRef => cast_fact.operand_id
    _ => -1
  }
  let descriptor_call_ref_id = match
    @ir.hot_node_get(func, cast_fact.descriptor_id).op {
    @ir.HotOp::CallRef => cast_fact.descriptor_id
    _ => -1
  }
  if operand_call_ref_id < 0 && descriptor_call_ref_id < 0 {
    None
  } else {
    Some({ operand_call_ref_id, descriptor_call_ref_id })
  }
}

///|
fn OiDescriptorCallRefDirectizationFact::directize_children(
  self : OiDescriptorCallRefDirectizationFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> Bool {
  let mut changed = false
  if self.operand_call_ref_id >= 0 {
    if optimize_instructions_try_directize_ref_func_call_ref(
        ctx,
        func,
        dead,
        self.operand_call_ref_id,
      ) {
      changed = true
    }
  }
  if self.descriptor_call_ref_id >= 0 {
    if optimize_instructions_try_directize_ref_func_call_ref(
        ctx,
        func,
        dead,
        self.descriptor_call_ref_id,
      ) {
      changed = true
    }
  }
  changed
}

///|
priv struct OiDescriptorOperandSimplificationFact {
  cast_fact : OiDescriptorCastFact
  directization_fact : OiDescriptorCallRefDirectizationFact?
  kind : OiDescriptorOperandSimplificationKind
}

///|
fn OiDescriptorOperandSimplificationFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorOperandSimplificationFact? {
  let cast_fact = match OiDescriptorCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let directization_fact = OiDescriptorCallRefDirectizationFact::from_cast_fact(
    func, cast_fact,
  )
  let has_directization_fact = match directization_fact {
    Some(_) => true
    None => false
  }
  let kind = match @ir.hot_node_exact_instr(func, cast_fact.descriptor_id) {
    Some(@lib.Instruction::RefAsNonNull) =>
      if @ir.hot_child_count(func, cast_fact.descriptor_id) == 1 {
        DescriptorOperandStripRefAsNonNull
      } else if has_directization_fact {
        DescriptorOperandDirectizeOnly
      } else {
        return None
      }
    Some(@lib.Instruction::RefGetDesc(_)) =>
      DescriptorOperandMoveRefGetDescNullCheck
    _ =>
      if has_directization_fact {
        DescriptorOperandDirectizeOnly
      } else {
        return None
      }
  }
  Some({ cast_fact, directization_fact, kind })
}

///|
priv struct OiDescriptorOperandSimplificationRewritePlanFact {
  simplification_fact : OiDescriptorOperandSimplificationFact
}

///|
fn OiDescriptorOperandSimplificationRewritePlanFact::from_fact(
  simplification_fact : OiDescriptorOperandSimplificationFact,
) -> OiDescriptorOperandSimplificationRewritePlanFact {
  // Binaryen v130 `visitRefCast` first lets descriptor-cast operands expose
  // simpler fallthrough/direct-call facts, then applies descriptor-operand
  // cleanup such as stripping a descriptor-side `ref.as_non_null` or moving the
  // nullable child through `ref.get_desc`. Keep that represented Starshine
  // sequence as one plan fact instead of a visitor-local cascade over call_ref,
  // descriptor wrapper, and ref.get_desc child shapes.
  { simplification_fact, }
}

///|
fn OiDescriptorOperandSimplificationRewritePlanFact::apply(
  self : OiDescriptorOperandSimplificationRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let fact = self.simplification_fact
  let cast_fact = fact.cast_fact
  let directized_children = match fact.directization_fact {
    Some(directization_fact) =>
      directization_fact.directize_children(ctx, func, dead)
    None => false
  }
  if optimize_instructions_try_skip_ref_cast_desc_eq_exact_success_traps_never_happen(
      ctx, func, node_id,
    ) ||
    optimize_instructions_try_skip_ref_cast_desc_eq_traps_never_happen(
      ctx, func, dead, node_id,
    ) {
    return true
  }
  match fact.kind {
    DescriptorOperandDirectizeOnly => directized_children
    DescriptorOperandStripRefAsNonNull => {
      @ir.hot_child_set(
        func,
        node_id,
        1,
        @ir.hot_child_get(func, cast_fact.descriptor_id, 0),
      )
      pass_mark_mutated(ctx, func)
      true
    }
    DescriptorOperandMoveRefGetDescNullCheck =>
      optimize_instructions_try_move_ref_get_desc_child_null_check(
        ctx,
        func,
        cast_fact.descriptor_id,
      ) ||
      directized_children
  }
}

///|
priv struct OiRefGetDescFact {
  child_id : Int
  nullable_child_id : Int
}

///|
fn OiRefGetDescFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefGetDescFact? {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefGetDesc(_)) => ()
    _ => return None
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  let nullable_child_id = match @ir.hot_node_exact_instr(func, child_id) {
    Some(@lib.Instruction::RefAsNonNull) if @ir.hot_child_count(func, child_id) ==
      1 => @ir.hot_child_get(func, child_id, 0)
    _ => -1
  }
  Some({ child_id, nullable_child_id })
}

///|
fn OiRefGetDescFact::explicit_nullable_child(self : OiRefGetDescFact) -> Int? {
  if self.nullable_child_id >= 0 {
    Some(self.nullable_child_id)
  } else {
    None
  }
}

///|
priv enum OiRefGetDescKnownNullChildKind {
  RefGetDescKnownNullDirectTrap
  RefGetDescKnownNullPreserveChild
}

///|
priv struct OiRefGetDescKnownNullChildFact {
  kind : OiRefGetDescKnownNullChildKind
  get_desc_fact : OiRefGetDescFact
  preserve_child_id : Int
}

///|
fn OiRefGetDescKnownNullChildFact::from_get_desc(
  func : @ir.HotFunc,
  get_desc_fact : OiRefGetDescFact,
) -> OiRefGetDescKnownNullChildFact? {
  // Binaryen v130 treats standalone `ref.get_desc(ref.as_non_null(child))`
  // with a provably null child as a null trap, while preserving child effects
  // that must remain before the trap. Keep that as a fact rather than letting
  // the visitor choose among nullable-child shape scanners directly.
  let nullable_child = match get_desc_fact.explicit_nullable_child() {
    Some(child) => child
    None => return None
  }
  match @ir.hot_node_get(func, nullable_child).op {
    @ir.HotOp::RefNull =>
      if OiStandaloneRefGetDescLeafFact::from_node(func, nullable_child).proves_known_null_ref_null_leaf() {
        Some({
          kind: RefGetDescKnownNullDirectTrap,
          get_desc_fact,
          preserve_child_id: -1,
        })
      } else {
        None
      }
    @ir.HotOp::LocalTee =>
      if OiStandaloneRefGetDescLocalTeeFact::from_node(func, nullable_child).proves_known_null_child() {
        Some({
          kind: RefGetDescKnownNullPreserveChild,
          get_desc_fact,
          preserve_child_id: nullable_child,
        })
      } else {
        None
      }
    @ir.HotOp::Block =>
      if OiStandaloneRefGetDescKnownNullBlockFact::from_block(
          func, nullable_child,
        ).proves_known_null_child() {
        Some({
          kind: RefGetDescKnownNullPreserveChild,
          get_desc_fact,
          preserve_child_id: nullable_child,
        })
      } else {
        None
      }
    _ => None
  }
}

///|
fn OiRefGetDescKnownNullChildFact::apply(
  self : OiRefGetDescKnownNullChildFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  ignore(self.get_desc_fact)
  match self.kind {
    RefGetDescKnownNullDirectTrap =>
      ignore(
        optimize_instructions_replace_with_unreachable(ctx, func, descriptor_id),
      )
    RefGetDescKnownNullPreserveChild =>
      ignore(
        optimize_instructions_replace_with_drop_then_unreachable(
          ctx,
          func,
          descriptor_id,
          self.preserve_child_id,
        ),
      )
  }
  true
}

///|
priv enum OiRefGetDescNullCheckMoveKind {
  RefGetDescStandaloneNullCheckMove
  RefGetDescDescriptorOperandNullCheckMove
  RefGetDescTrapsNeverHappenNullCheckMove
}

///|
priv enum OiRefGetDescNullableChildMoveKind {
  RefGetDescNullableLeafMove
  RefGetDescNullableLocalTeeMove
  RefGetDescNullableCallMove
  RefGetDescNullableSelectMove
  RefGetDescNullableIfMove
  RefGetDescNullableBlockMove
}

///|
priv struct OiRefGetDescNullableChildMoveFact {
  child_id : Int
  child_kind : OiRefGetDescNullableChildMoveKind
  standalone_can_move : Bool
  descriptor_operand_can_move : Bool
}

///|
fn OiRefGetDescNullableChildMoveFact::from_child(
  func : @ir.HotFunc,
  child_id : Int,
) -> OiRefGetDescNullableChildMoveFact? {
  // Binaryen v130 commonly strips `ref.as_non_null` under `ref.get_desc` when
  // the nullable child is already the value that should be described. Keep the
  // represented Starshine child-shape boundaries in a fact instead of letting
  // each ref.get_desc caller branch on local/block/select/if/call shapes.
  let child = @ir.hot_node_get(func, child_id)
  let child_kind = match child.op {
    @ir.HotOp::LocalGet | @ir.HotOp::GlobalGet =>
      if OiStandaloneRefGetDescLeafFact::from_node(func, child_id).proves_nullable_ref_leaf_can_move_null_check() {
        RefGetDescNullableLeafMove
      } else {
        return None
      }
    @ir.HotOp::LocalTee =>
      if OiStandaloneRefGetDescLocalTeeFact::from_node(func, child_id).proves_can_move_null_check() {
        RefGetDescNullableLocalTeeMove
      } else {
        return None
      }
    @ir.HotOp::Call | @ir.HotOp::CallIndirect =>
      if OiStandaloneRefGetDescCallMoveFact::from_call(func, child_id).proves_can_move_null_check() {
        RefGetDescNullableCallMove
      } else {
        return None
      }
    @ir.HotOp::Select =>
      if OiResultShapeFact::from_node(func, child_id).proves_single_nullable_ref_result() &&
        !OiDescriptorBranchControlFact::from_node(func, child_id, child_id).proves_has_escaping_branch_control() {
        RefGetDescNullableSelectMove
      } else {
        return None
      }
    @ir.HotOp::If =>
      if OiResultShapeFact::from_node(func, child_id).proves_single_nullable_ref_result() &&
        OiDescriptorNullableIfControlMoveFact::from_if(func, child_id).proves_can_move_null_check() {
        RefGetDescNullableIfMove
      } else {
        return None
      }
    @ir.HotOp::Block =>
      if OiStandaloneRefGetDescBlockMoveFact::from_block(func, child_id).proves_can_move_null_check() {
        RefGetDescNullableBlockMove
      } else {
        return None
      }
    _ => return None
  }
  let descriptor_operand_can_move = match child.op {
    @ir.HotOp::LocalGet => true
    @ir.HotOp::Block | @ir.HotOp::Select =>
      !OiDescriptorBranchControlFact::from_node(func, child_id, child_id).proves_has_escaping_branch_control()
    @ir.HotOp::If =>
      OiDescriptorNullableIfControlMoveFact::from_if(func, child_id).proves_can_move_null_check()
    _ => false
  }
  Some({
    child_id,
    child_kind,
    standalone_can_move: true,
    descriptor_operand_can_move,
  })
}

///|
fn OiRefGetDescNullableChildMoveFact::can_move_for(
  self : OiRefGetDescNullableChildMoveFact,
  kind : OiRefGetDescNullCheckMoveKind,
) -> Bool {
  ignore(self.child_id)
  let supported_shape = match self.child_kind {
    RefGetDescNullableLeafMove
    | RefGetDescNullableLocalTeeMove
    | RefGetDescNullableCallMove
    | RefGetDescNullableSelectMove
    | RefGetDescNullableIfMove
    | RefGetDescNullableBlockMove => true
  }
  if !supported_shape {
    return false
  }
  match kind {
    RefGetDescTrapsNeverHappenNullCheckMove => true
    RefGetDescStandaloneNullCheckMove => self.standalone_can_move
    RefGetDescDescriptorOperandNullCheckMove => self.descriptor_operand_can_move
  }
}

///|
priv struct OiRefGetDescNullCheckMoveFact {
  kind : OiRefGetDescNullCheckMoveKind
  get_desc_fact : OiRefGetDescFact
  nullable_child_id : Int
}

///|
fn OiRefGetDescNullCheckMoveFact::from_get_desc(
  func : @ir.HotFunc,
  get_desc_fact : OiRefGetDescFact,
  kind : OiRefGetDescNullCheckMoveKind,
) -> OiRefGetDescNullCheckMoveFact? {
  // Binaryen v130 commonly moves or removes the explicit `ref.as_non_null`
  // child check under `ref.get_desc` when the nullable producer can be kept as
  // the descriptor operand. Represent the mode-specific safety proof here so
  // ref.get_desc callers request a plan instead of branching on raw child ops.
  let nullable_child = match get_desc_fact.explicit_nullable_child() {
    Some(child) => child
    None => return None
  }
  let allowed = match kind {
    RefGetDescTrapsNeverHappenNullCheckMove => true
    _ =>
      match
        OiRefGetDescNullableChildMoveFact::from_child(func, nullable_child) {
        Some(child_fact) => child_fact.can_move_for(kind)
        None => false
      }
  }
  if !allowed {
    return None
  }
  Some({ kind, get_desc_fact, nullable_child_id: nullable_child })
}

///|
fn OiRefGetDescNullCheckMoveFact::apply(
  self : OiRefGetDescNullCheckMoveFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  ignore(self.kind)
  ignore(self.get_desc_fact)
  @ir.hot_child_set(func, descriptor_id, 0, self.nullable_child_id)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn OiRefGetDescFact::child_is_unreachable(
  self : OiRefGetDescFact,
  func : @ir.HotFunc,
) -> Bool {
  match @ir.hot_node_get(func, self.child_id).op {
    @ir.HotOp::Unreachable => true
    _ => false
  }
}

///|
priv struct OptimizeInstructionsScratch {
  cross_seen_stamps : Array[Int]
  loop_input_nodes : @bitset.BitSet
  if_condition_nodes : @bitset.BitSet
  local_facts : OptimizeInstructionsLocalFacts
  mut loop_input_nodes_ready : Bool
  mut if_condition_nodes_ready : Bool
  mut next_cross_seen_stamp : Int
}

///|
fn OptimizeInstructionsScratch::new(
  node_count : Int,
  local_count : Int,
) -> OptimizeInstructionsScratch {
  {
    cross_seen_stamps: Array::make(node_count, -1),
    loop_input_nodes: @bitset.BitSet::new(node_count),
    if_condition_nodes: @bitset.BitSet::new(node_count),
    local_facts: OptimizeInstructionsLocalFacts::new(local_count),
    loop_input_nodes_ready: false,
    if_condition_nodes_ready: false,
    next_cross_seen_stamp: 0,
  }
}

///|
fn optimize_instructions_alloc_cross_seen_stamp(
  scratch : OptimizeInstructionsScratch,
) -> Int {
  let stamp = scratch.next_cross_seen_stamp
  scratch.next_cross_seen_stamp = stamp + 1
  stamp
}

///|
fn optimize_instructions_mark_loop_input_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.loop_input_nodes_ready {
    return
  }
  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    match node.op {
      @ir.HotOp::Loop => ()
      _ => continue
    }
    let input_count = @ir.hot_label_branch_arity(
      func,
      @ir.hot_control_node_label(func, node_id),
    )
    for slot = 0; slot < input_count; slot = slot + 1 {
      let child_id = func.children[node.child_base + slot]
      if child_id >= 0 && child_id < scratch.loop_input_nodes.length() {
        scratch.loop_input_nodes[child_id] = true
      }
    }
  }
  scratch.loop_input_nodes_ready = true
}

///|
fn optimize_instructions_mark_if_condition_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.if_condition_nodes_ready {
    return
  }
  for node_id = 0; node_id < func.nodes.length(); node_id = node_id + 1 {
    if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
      continue
    }
    let node = func.nodes[node_id]
    match node.op {
      @ir.HotOp::If if node.child_count > 0 => {
        let cond_id = func.children[node.child_base]
        if cond_id >= 0 && cond_id < scratch.if_condition_nodes.length() {
          scratch.if_condition_nodes[cond_id] = true
        }
      }
      _ => ()
    }
  }
  scratch.if_condition_nodes_ready = true
}

///|
fn optimize_instructions_sign_ext_bits_for_exact_instr(
  instr : @lib.Instruction,
) -> Int {
  match instr {
    @lib.Instruction::I32Load8S(_) | @lib.Instruction::I64Load8S(_) => 8
    @lib.Instruction::I32Load16S(_) | @lib.Instruction::I64Load16S(_) => 16
    @lib.Instruction::I64Load32S(_) => 32
    @lib.Instruction::I32Extend8S | @lib.Instruction::I64Extend8S => 8
    @lib.Instruction::I32Extend16S | @lib.Instruction::I64Extend16S => 16
    @lib.Instruction::I64Extend32S => 32
    _ => 0
  }
}

///|
fn optimize_instructions_i32_sign_ext_bits_for_const(raw : Int) -> Int {
  if raw >= -128 && raw <= 127 {
    8
  } else if raw >= -32768 && raw <= 32767 {
    16
  } else {
    32
  }
}

///|
fn optimize_instructions_i64_sign_ext_bits_for_const(raw : Int64) -> Int {
  if raw >= -128L && raw <= 127L {
    8
  } else if raw >= -32768L && raw <= 32767L {
    16
  } else if raw >= -2147483648L && raw <= 2147483647L {
    32
  } else {
    64
  }
}

///|
priv struct OiSignExtValueFact {
  bits : Int
}

///|
fn OiSignExtValueFact::from_bits(bits : Int) -> OiSignExtValueFact {
  { bits, }
}

///|
fn OiSignExtValueFact::from_node_with_local_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  node_id : Int,
) -> OiSignExtValueFact {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return OiSignExtValueFact::from_bits(0)
  }
  let node = @ir.hot_node_get(func, node_id)
  let bits = match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(raw)) =>
          optimize_instructions_i32_sign_ext_bits_for_const(raw)
        @ir.HotConstPayload::I64Const(@lib.I64(raw)) =>
          optimize_instructions_i64_sign_ext_bits_for_const(raw)
        _ => 0
      }
    @ir.HotOp::LocalGet =>
      match local_facts {
        Some(facts) => facts.sign_ext_bits_for_get(node.imm0)
        None => 0
      }
    @ir.HotOp::Load | @ir.HotOp::Unary =>
      optimize_instructions_sign_ext_bits_for_exact_instr(
        func.instr_payloads[node.imm0].instr,
      )
    _ => 0
  }
  OiSignExtValueFact::from_bits(bits)
}

///|
fn OiSignExtValueFact::from_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> OiSignExtValueFact {
  OiSignExtValueFact::from_node_with_local_facts(
    func,
    dead,
    Some(scratch.local_facts),
    node_id,
  )
}

///|
fn OiSignExtValueFact::from_assigned_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiSignExtValueFact {
  // Binaryen's LocalScanner computes the value fact for an assignment from the
  // assigned expression itself, not from the local fact being built. Keep that
  // no-local-get boundary explicit so self-referential local.set/tee shapes do
  // not smuggle stale scan state into the whole-function summary.
  OiSignExtValueFact::from_node_with_local_facts(func, dead, None, node_id)
}

///|
fn optimize_instructions_sign_ext_bits_for_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int {
  OiSignExtValueFact::from_value(func, dead, scratch, node_id).bits
}

///|
fn optimize_instructions_collect_sign_ext_local_assignment_region(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  region : @ir.HotRegionRef,
) -> Unit {
  for i = 0; i < @ir.hot_region_root_count(func, region); i = i + 1 {
    optimize_instructions_collect_sign_ext_local_assignment_expr(
      func,
      dead,
      scratch,
      @ir.hot_region_get(func, region, i),
    )
  }
}

///|
fn optimize_instructions_collect_sign_ext_local_assignment_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Unit {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_collect_sign_ext_local_assignment_expr(
      func,
      dead,
      scratch,
      func.children[node.child_base + slot],
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_collect_sign_ext_local_assignment_region(
        func,
        dead,
        scratch,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      optimize_instructions_collect_sign_ext_local_assignment_region(
        func,
        dead,
        scratch,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_collect_sign_ext_local_assignment_region(
            func, dead, scratch, else_region,
          )
        None => ()
      }
    }
    _ => {
      let assignment_fact = OiLocalAssignmentFact::from_node(
        func, dead, node_id,
      )
      if assignment_fact.proves_sign_ext_integer_local() {
        scratch.local_facts.merge_sign_ext_bits_for_local(
          assignment_fact.local_id,
          OiSignExtValueFact::from_assigned_value(
            func,
            dead,
            assignment_fact.value_id,
          ).bits,
        )
      }
    }
  }
}

///|
fn optimize_instructions_collect_sign_ext_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.local_facts.sign_ext_ready {
    return
  }
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    optimize_instructions_collect_sign_ext_local_assignment_expr(
      func,
      dead,
      scratch,
      func.roots[slot],
    )
  }
  scratch.local_facts.finalize_sign_ext_bits()
  scratch.local_facts.sign_ext_ready = true
}

///|
priv struct OiUnsignedMaxValueFact {
  i32_max : Int?
  i64_max : Int64?
}

///|
fn OiUnsignedMaxValueFact::i32_bits_for_max(max_value : Int) -> Int {
  let mut bits = 0
  let mut value = max_value
  while value > 0 {
    value = value >> 1
    bits = bits + 1
  }
  bits
}

///|
fn OiUnsignedMaxValueFact::i64_bits_for_max(max_value : Int64) -> Int {
  let mut bits = 0
  let mut value = max_value
  while value > 0L {
    value = value >> 1
    bits = bits + 1
  }
  bits
}

///|
fn OiUnsignedMaxValueFact::i32_max_for_bits(max_bits : Int) -> Int? {
  if max_bits < 0 || max_bits > 31 {
    None
  } else if max_bits == 0 {
    Some(0)
  } else {
    Some((1 << max_bits) - 1)
  }
}

///|
fn OiUnsignedMaxValueFact::i64_max_for_bits(max_bits : Int) -> Int64? {
  if max_bits < 0 || max_bits > 63 {
    None
  } else if max_bits == 0 {
    Some(0L)
  } else {
    Some((1L << max_bits) - 1L)
  }
}

///|
fn OiUnsignedMaxValueFact::i32_max_bits_or_unknown(max_value : Int?) -> Int {
  match max_value {
    Some(value) => OiUnsignedMaxValueFact::i32_bits_for_max(value)
    None => 32
  }
}

///|
fn OiUnsignedMaxValueFact::i64_max_bits_or_unknown(max_value : Int64?) -> Int {
  match max_value {
    Some(value) => OiUnsignedMaxValueFact::i64_bits_for_max(value)
    None => 64
  }
}

///|
fn OiUnsignedMaxValueFact::i32_max_for_bitwise_and(
  lhs_max : Int?,
  rhs_max : Int?,
) -> Int? {
  match (lhs_max, rhs_max) {
    (Some(lhs), Some(rhs)) => Some(if lhs < rhs { lhs } else { rhs })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn OiUnsignedMaxValueFact::i64_max_for_bitwise_and(
  lhs_max : Int64?,
  rhs_max : Int64?,
) -> Int64? {
  match (lhs_max, rhs_max) {
    (Some(lhs), Some(rhs)) => Some(if lhs < rhs { lhs } else { rhs })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn OiUnsignedMaxValueFact::i32_max_for_bitwise_union(
  lhs_max : Int?,
  rhs_max : Int?,
) -> Int? {
  let lhs_bits = OiUnsignedMaxValueFact::i32_max_bits_or_unknown(lhs_max)
  let rhs_bits = OiUnsignedMaxValueFact::i32_max_bits_or_unknown(rhs_max)
  let max_bits = if lhs_bits > rhs_bits { lhs_bits } else { rhs_bits }
  OiUnsignedMaxValueFact::i32_max_for_bits(max_bits)
}

///|
fn OiUnsignedMaxValueFact::i64_max_for_bitwise_union(
  lhs_max : Int64?,
  rhs_max : Int64?,
) -> Int64? {
  let lhs_bits = OiUnsignedMaxValueFact::i64_max_bits_or_unknown(lhs_max)
  let rhs_bits = OiUnsignedMaxValueFact::i64_max_bits_or_unknown(rhs_max)
  let max_bits = if lhs_bits > rhs_bits { lhs_bits } else { rhs_bits }
  OiUnsignedMaxValueFact::i64_max_for_bits(max_bits)
}

///|
priv struct OiArithmeticMaxBitsFact {
  width_bits : Int
  max_bits : Int
}

///|
fn OiArithmeticMaxBitsFact::cap(width_bits : Int, max_bits : Int) -> Int {
  if max_bits > width_bits {
    width_bits
  } else {
    max_bits
  }
}

///|
fn OiArithmeticMaxBitsFact::binary_i32(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> OiArithmeticMaxBitsFact? {
  // Binaryen v130 `Bits::getMaxBits` derives arithmetic max-bit counts from
  // operand max bits for add, multiply, constant left shift, and arithmetic
  // right shift. Keep those derivations in one source-backed fact so downstream
  // zero-bit, signed-to-unsigned, and wrap/extend consumers do not grow their
  // own operator whitelists.
  let lhs_max = OiUnsignedMaxValueFact::i32_max_for_node(
    func, dead, local_facts, lhs_id,
  )
  let lhs_bits = OiUnsignedMaxValueFact::i32_max_bits_or_unknown(lhs_max)
  let max_bits = match instr {
    @lib.Instruction::I32Add => {
      let rhs_bits = OiUnsignedMaxValueFact::i32_max_bits_or_unknown(
        OiUnsignedMaxValueFact::i32_max_for_node(
          func, dead, local_facts, rhs_id,
        ),
      )
      let operand_bits = if lhs_bits > rhs_bits { lhs_bits } else { rhs_bits }
      Some(OiArithmeticMaxBitsFact::cap(32, operand_bits + 1))
    }
    @lib.Instruction::I32Mul => {
      let rhs_bits = OiUnsignedMaxValueFact::i32_max_bits_or_unknown(
        OiUnsignedMaxValueFact::i32_max_for_node(
          func, dead, local_facts, rhs_id,
        ),
      )
      Some(OiArithmeticMaxBitsFact::cap(32, lhs_bits + rhs_bits))
    }
    @lib.Instruction::I32Shl =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw >= 0 && raw < 32 =>
          Some(OiArithmeticMaxBitsFact::cap(32, lhs_bits + raw))
        _ => None
      }
    @lib.Instruction::I32ShrS =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw >= 0 && raw < 32 && lhs_bits < 32 => {
          let shifts = if raw < lhs_bits { raw } else { lhs_bits }
          Some(lhs_bits - shifts)
        }
        _ => None
      }
    _ => None
  }
  match max_bits {
    Some(bits) => Some({ width_bits: 32, max_bits: bits })
    None => None
  }
}

///|
fn OiArithmeticMaxBitsFact::binary_i64(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> OiArithmeticMaxBitsFact? {
  // Same Binaryen v130 arithmetic `Bits::getMaxBits` family as `binary_i32`,
  // specialized for i64 widths and i64-typed shift operands in Starshine HOT.
  let lhs_max = OiUnsignedMaxValueFact::i64_max_for_node(
    func, dead, local_facts, lhs_id,
  )
  let lhs_bits = OiUnsignedMaxValueFact::i64_max_bits_or_unknown(lhs_max)
  let max_bits = match instr {
    @lib.Instruction::I64Add => {
      let rhs_bits = OiUnsignedMaxValueFact::i64_max_bits_or_unknown(
        OiUnsignedMaxValueFact::i64_max_for_node(
          func, dead, local_facts, rhs_id,
        ),
      )
      let operand_bits = if lhs_bits > rhs_bits { lhs_bits } else { rhs_bits }
      Some(OiArithmeticMaxBitsFact::cap(64, operand_bits + 1))
    }
    @lib.Instruction::I64Mul => {
      let rhs_bits = OiUnsignedMaxValueFact::i64_max_bits_or_unknown(
        OiUnsignedMaxValueFact::i64_max_for_node(
          func, dead, local_facts, rhs_id,
        ),
      )
      Some(OiArithmeticMaxBitsFact::cap(64, lhs_bits + rhs_bits))
    }
    @lib.Instruction::I64Shl =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) if raw >= 0L && raw < 64L =>
          Some(OiArithmeticMaxBitsFact::cap(64, lhs_bits + raw.to_int()))
        _ => None
      }
    @lib.Instruction::I64ShrS =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) if raw >= 0L && raw < 64L && lhs_bits < 64 => {
          let shift = raw.to_int()
          let shifts = if shift < lhs_bits { shift } else { lhs_bits }
          Some(lhs_bits - shifts)
        }
        _ => None
      }
    _ => None
  }
  match max_bits {
    Some(bits) => Some({ width_bits: 64, max_bits: bits })
    None => None
  }
}

///|
fn OiUnsignedMaxValueFact::from_i32_max(
  max_value : Int?,
) -> OiUnsignedMaxValueFact {
  { i32_max: max_value, i64_max: None }
}

///|
fn OiUnsignedMaxValueFact::from_i64_max(
  max_value : Int64?,
) -> OiUnsignedMaxValueFact {
  { i32_max: None, i64_max: max_value }
}

///|
fn OiUnsignedMaxValueFact::from_i32_node_with_local_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  node_id : Int,
) -> OiUnsignedMaxValueFact {
  let max_value = OiUnsignedMaxValueFact::i32_max_for_node(
    func, dead, local_facts, node_id,
  )
  OiUnsignedMaxValueFact::from_i32_max(max_value)
}

///|
fn OiUnsignedMaxValueFact::from_i64_node_with_local_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  node_id : Int,
) -> OiUnsignedMaxValueFact {
  let max_value = OiUnsignedMaxValueFact::i64_max_for_node(
    func, dead, local_facts, node_id,
  )
  OiUnsignedMaxValueFact::from_i64_max(max_value)
}

///|
fn OiUnsignedMaxValueFact::from_i32_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> OiUnsignedMaxValueFact {
  OiUnsignedMaxValueFact::from_i32_node_with_local_facts(
    func,
    dead,
    Some(scratch.local_facts),
    node_id,
  )
}

///|
fn OiUnsignedMaxValueFact::from_i64_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> OiUnsignedMaxValueFact {
  OiUnsignedMaxValueFact::from_i64_node_with_local_facts(
    func,
    dead,
    Some(scratch.local_facts),
    node_id,
  )
}

///|
fn OiUnsignedMaxValueFact::from_assigned_i32_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiUnsignedMaxValueFact {
  // Assignment facts seed the LocalScanner-like summary. They deliberately do
  // not recurse through LocalGet summaries, matching the conservative previous
  // scanner behavior for local-carried and self-referential values.
  OiUnsignedMaxValueFact::from_i32_node_with_local_facts(
    func,
    dead,
    None,
    node_id,
  )
}

///|
fn OiUnsignedMaxValueFact::from_assigned_i64_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiUnsignedMaxValueFact {
  // Assignment facts seed the LocalScanner-like summary. They deliberately do
  // not recurse through LocalGet summaries, matching the conservative previous
  // scanner behavior for local-carried and self-referential values.
  OiUnsignedMaxValueFact::from_i64_node_with_local_facts(
    func,
    dead,
    None,
    node_id,
  )
}

///|
priv struct OiBooleanI32MaxBitsFact {
  value_id : Int
}

///|
fn OiBooleanI32MaxBitsFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiBooleanI32MaxBitsFact? {
  // Binaryen v130 `Bits::getMaxBits` treats integer comparisons and `eqz`
  // results as i32 booleans, so they require at most one bit. Keep this as an
  // explicit fact instead of scattering compare/eqz whitelists across maxBits
  // consumers.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Compare => Some({ value_id: node_id })
    @ir.HotOp::Unary =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I32Eqz) | Some(@lib.Instruction::I64Eqz) =>
          Some({ value_id: node_id })
        _ => None
      }
    _ => None
  }
}

///|
fn OiUnsignedMaxValueFact::i32_max_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  node_id : Int,
) -> Int? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Load8U(_)) => return Some(255)
    Some(@lib.Instruction::I32Load16U(_)) => return Some(65535)
    _ => ()
  }
  match OiBooleanI32MaxBitsFact::from_node(func, dead, node_id) {
    Some(fact) => {
      ignore(fact.value_id)
      return Some(1)
    }
    None => ()
  }
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(raw)) if raw >= 0 => Some(raw)
        _ => None
      }
    @ir.HotOp::LocalGet =>
      match local_facts {
        Some(facts) => facts.i32_unsigned_max_for_get(node.imm0)
        None => None
      }
    @ir.HotOp::Unary | @ir.HotOp::Convert => {
      let operand_id = func.children[node.child_base]
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I32WrapI64) =>
          match
            OiUnsignedMaxValueFact::i64_max_for_node(
              func, dead, local_facts, operand_id,
            ) {
            Some(max_value) if max_value <= 2147483647L =>
              Some(max_value.to_int())
            _ => None
          }
        _ => None
      }
    }
    @ir.HotOp::Binary => {
      let lhs_id = func.children[node.child_base]
      let rhs_id = func.children[node.child_base + 1]
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I32And) => {
          // Binaryen v130 `Bits::getMaxBits` treats bitwise-and as the minimum
          // of the operands' max-bit counts. Preserve that source rule through
          // the stronger max-value fact instead of requiring a nonnegative direct
          // mask: a negative mask still keeps a bounded left operand bounded,
          // and two nonconstant bounded operands can feed the same proof.
          let lhs_max = OiUnsignedMaxValueFact::i32_max_for_node(
            func, dead, local_facts, lhs_id,
          )
          let rhs_max = OiUnsignedMaxValueFact::i32_max_for_node(
            func, dead, local_facts, rhs_id,
          )
          OiUnsignedMaxValueFact::i32_max_for_bitwise_and(lhs_max, rhs_max)
        }
        Some(@lib.Instruction::I32Or) | Some(@lib.Instruction::I32Xor) => {
          // Binaryen v130 `Bits::getMaxBits` keeps `or`/`xor` at the maximum of
          // the operands' max-bit counts. Return the low-ones maximum implied by
          // that fact; it is intentionally a maxBits fact, not an exact value
          // range for the expression.
          let lhs_max = OiUnsignedMaxValueFact::i32_max_for_node(
            func, dead, local_facts, lhs_id,
          )
          let rhs_max = OiUnsignedMaxValueFact::i32_max_for_node(
            func, dead, local_facts, rhs_id,
          )
          OiUnsignedMaxValueFact::i32_max_for_bitwise_union(lhs_max, rhs_max)
        }
        Some(@lib.Instruction::I32ShrU) =>
          match optimize_instructions_i32_const(func, dead, rhs_id) {
            Some(@lib.I32(raw)) if raw > 0 && raw < 32 =>
              match
                OiUnsignedMaxValueFact::i32_max_for_node(
                  func, dead, local_facts, lhs_id,
                ) {
                Some(value) => Some(value >> raw)
                None if raw == 1 => Some(2147483647)
                None => Some((1 << (32 - raw)) - 1)
              }
            _ => None
          }
        Some(instr) =>
          match
            OiArithmeticMaxBitsFact::binary_i32(
              func, dead, local_facts, instr, lhs_id, rhs_id,
            ) {
            Some(fact) => {
              ignore(fact.width_bits)
              OiUnsignedMaxValueFact::i32_max_for_bits(fact.max_bits)
            }
            None => None
          }
        _ => None
      }
    }
    @ir.HotOp::Block if node.child_count == 1 =>
      OiUnsignedMaxValueFact::i32_max_for_node(
        func,
        dead,
        local_facts,
        func.children[node.child_base],
      )
    _ => None
  }
}

///|
fn OiUnsignedMaxValueFact::i64_max_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  node_id : Int,
) -> Int64? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I64Load8U(_)) => return Some(255L)
    Some(@lib.Instruction::I64Load16U(_)) => return Some(65535L)
    Some(@lib.Instruction::I64Load32U(_)) => return Some(4294967295L)
    _ => ()
  }
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I64Const(@lib.I64(raw)) if raw >= 0L => Some(raw)
        _ => None
      }
    @ir.HotOp::LocalGet =>
      match local_facts {
        Some(facts) => facts.i64_unsigned_max_for_get(node.imm0)
        None => None
      }
    @ir.HotOp::Unary | @ir.HotOp::Convert => {
      let operand_id = func.children[node.child_base]
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I64ExtendI32U) =>
          match
            OiUnsignedMaxValueFact::i32_max_for_node(
              func, dead, local_facts, operand_id,
            ) {
            Some(value) => Some(value.to_int64())
            None => Some(4294967295L)
          }
        _ =>
          OiUnsignedMaxValueFact::i32_max_for_node(
            func, dead, local_facts, operand_id,
          ).map(fn(value) { value.to_int64() })
      }
    }
    @ir.HotOp::Binary => {
      let lhs_id = func.children[node.child_base]
      let rhs_id = func.children[node.child_base + 1]
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::I64And) => {
          // Binaryen v130 `Bits::getMaxBits` treats bitwise-and as the minimum
          // of the operands' max-bit counts. Preserve that source rule through
          // the stronger max-value fact instead of requiring a nonnegative direct
          // mask: a negative mask still keeps a bounded left operand bounded,
          // and two nonconstant bounded operands can feed the same proof.
          let lhs_max = OiUnsignedMaxValueFact::i64_max_for_node(
            func, dead, local_facts, lhs_id,
          )
          let rhs_max = OiUnsignedMaxValueFact::i64_max_for_node(
            func, dead, local_facts, rhs_id,
          )
          OiUnsignedMaxValueFact::i64_max_for_bitwise_and(lhs_max, rhs_max)
        }
        Some(@lib.Instruction::I64Or) | Some(@lib.Instruction::I64Xor) => {
          // Binaryen v130 `Bits::getMaxBits` keeps `or`/`xor` at the maximum of
          // the operands' max-bit counts. Return the low-ones maximum implied by
          // that fact; it is intentionally a maxBits fact, not an exact value
          // range for the expression.
          let lhs_max = OiUnsignedMaxValueFact::i64_max_for_node(
            func, dead, local_facts, lhs_id,
          )
          let rhs_max = OiUnsignedMaxValueFact::i64_max_for_node(
            func, dead, local_facts, rhs_id,
          )
          OiUnsignedMaxValueFact::i64_max_for_bitwise_union(lhs_max, rhs_max)
        }
        Some(@lib.Instruction::I64ShrU) =>
          match optimize_instructions_i64_const(func, dead, rhs_id) {
            Some(@lib.I64(raw)) if raw > 0L && raw < 64L =>
              match
                OiUnsignedMaxValueFact::i64_max_for_node(
                  func, dead, local_facts, lhs_id,
                ) {
                Some(value) => Some(value >> raw.to_int())
                None if raw == 1L => Some(9223372036854775807L)
                None => Some((1L << (64 - raw.to_int())) - 1L)
              }
            _ => None
          }
        Some(instr) =>
          match
            OiArithmeticMaxBitsFact::binary_i64(
              func, dead, local_facts, instr, lhs_id, rhs_id,
            ) {
            Some(fact) => {
              ignore(fact.width_bits)
              OiUnsignedMaxValueFact::i64_max_for_bits(fact.max_bits)
            }
            None => None
          }
        _ => None
      }
    }
    @ir.HotOp::Block if node.child_count == 1 =>
      OiUnsignedMaxValueFact::i64_max_for_node(
        func,
        dead,
        local_facts,
        func.children[node.child_base],
      )
    _ => None
  }
}

///|
fn optimize_instructions_i32_unsigned_max_fact_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int? {
  OiUnsignedMaxValueFact::from_i32_value(func, dead, scratch, node_id).i32_max
}

///|
priv struct OiEqzWrapI64MaxBitsFact {
  value_id : Int
}

///|
fn OiEqzWrapI64MaxBitsFact::from_eqz_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  instr : @lib.Instruction,
  operand_id : Int,
) -> OiEqzWrapI64MaxBitsFact? {
  // Binaryen v130 rewrites `i32.eqz(i32.wrap_i64(x))` to `i64.eqz(x)` when
  // `Bits::getMaxBits(x) <= 32`. Reuse the shared unsigned-max fact instead of
  // adding a local wrapper scanner so all source-backed maxBits producers feed
  // this consumer.
  match instr {
    @lib.Instruction::I32Eqz => ()
    _ => return None
  }
  match @ir.hot_node_exact_instr(func, operand_id) {
    Some(@lib.Instruction::I32WrapI64) if @ir.hot_child_count(func, operand_id) ==
      1 => ()
    _ => return None
  }
  let value_id = @ir.hot_child_get(func, operand_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, value_id) {
    return None
  }
  match
    OiUnsignedMaxValueFact::from_i64_value(func, dead, scratch, value_id).i64_max {
    Some(max_value) if max_value <= 4294967295L => Some({ value_id, })
    _ => None
  }
}

///|
fn optimize_instructions_i64_unsigned_max_fact_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int64? {
  OiUnsignedMaxValueFact::from_i64_value(func, dead, scratch, node_id).i64_max
}

///|
priv struct OiExtendWrapI64MaxBitsFact {
  value_id : Int
}

///|
priv enum OiZeroBitsReplacementKind {
  ZeroBitsI32
  ZeroBitsI64
}

///|
priv struct OiZeroBitsReplacementFact {
  kind : OiZeroBitsReplacementKind
}

///|
fn OiZeroBitsReplacementFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> OiZeroBitsReplacementFact? {
  // Binaryen v130 `replaceZeroBitsWithZero` replaces non-constant integer
  // expressions when `Bits::getMaxBits(curr) == 0`, delegating effect
  // preservation to `getDroppedChildrenAndAppend`. This first Starshine fact
  // covers the pure expression subset represented by `OiSideEffectFreeExpressionFact`;
  // effect-preserving dropped-child materialization remains a documented boundary.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Const => return None
    _ => ()
  }
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, node_id) {
    return None
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [value_type] if value_type == @lib.ValType::i32() =>
      match
        OiUnsignedMaxValueFact::from_i32_value(func, dead, scratch, node_id).i32_max {
        Some(0) => Some({ kind: ZeroBitsI32 })
        _ => None
      }
    [value_type] if value_type == @lib.ValType::i64() =>
      match
        OiUnsignedMaxValueFact::from_i64_value(func, dead, scratch, node_id).i64_max {
        Some(0L) => Some({ kind: ZeroBitsI64 })
        _ => None
      }
    _ => None
  }
}

///|
fn OiZeroBitsReplacementFact::apply(
  self : OiZeroBitsReplacementFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  match self.kind {
    ZeroBitsI32 =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(0),
      )
    ZeroBitsI64 =>
      optimize_instructions_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(0L),
      )
  }
}

///|
fn OiExtendWrapI64MaxBitsFact::from_extend_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  instr : @lib.Instruction,
  operand_id : Int,
) -> OiExtendWrapI64MaxBitsFact? {
  // Binaryen v130 rewrites `i64.extend_i32_s(i32.wrap_i64(x))` to `x` when
  // `Bits::getMaxBits(x) <= 31`, and the unsigned spelling when maxBits <= 32.
  // Use the shared unsigned-max fact so all source-backed maxBits producers feed
  // the extend-wrap consumer instead of adding another wrapper-specific scanner.
  let max_value_limit = match instr {
    @lib.Instruction::I64ExtendI32S => 2147483647L
    @lib.Instruction::I64ExtendI32U => 4294967295L
    _ => return None
  }
  match @ir.hot_node_exact_instr(func, operand_id) {
    Some(@lib.Instruction::I32WrapI64) if @ir.hot_child_count(func, operand_id) ==
      1 => ()
    _ => return None
  }
  let value_id = @ir.hot_child_get(func, operand_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, value_id) {
    return None
  }
  match
    OiUnsignedMaxValueFact::from_i64_value(func, dead, scratch, value_id).i64_max {
    Some(max_value) if max_value <= max_value_limit => Some({ value_id, })
    _ => None
  }
}

///|
fn optimize_instructions_collect_unsigned_max_local_assignment_region(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  region : @ir.HotRegionRef,
) -> Unit {
  for i = 0; i < @ir.hot_region_root_count(func, region); i = i + 1 {
    optimize_instructions_collect_unsigned_max_local_assignment_expr(
      func,
      dead,
      scratch,
      @ir.hot_region_get(func, region, i),
    )
  }
}

///|
fn optimize_instructions_collect_unsigned_max_local_assignment_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Unit {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_collect_unsigned_max_local_assignment_expr(
      func,
      dead,
      scratch,
      func.children[node.child_base + slot],
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_collect_unsigned_max_local_assignment_region(
        func,
        dead,
        scratch,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      optimize_instructions_collect_unsigned_max_local_assignment_region(
        func,
        dead,
        scratch,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_collect_unsigned_max_local_assignment_region(
            func, dead, scratch, else_region,
          )
        None => ()
      }
    }
    _ => {
      let assignment_fact = OiLocalAssignmentFact::from_node(
        func, dead, node_id,
      )
      if assignment_fact.proves_i32_local() {
        scratch.local_facts.merge_i32_unsigned_max_for_local(
          assignment_fact.local_id,
          OiUnsignedMaxValueFact::from_assigned_i32_value(
            func,
            dead,
            assignment_fact.value_id,
          ).i32_max,
        )
      } else if assignment_fact.proves_i64_local() {
        scratch.local_facts.merge_i64_unsigned_max_for_local(
          assignment_fact.local_id,
          OiUnsignedMaxValueFact::from_assigned_i64_value(
            func,
            dead,
            assignment_fact.value_id,
          ).i64_max,
        )
      }
    }
  }
}

///|
fn optimize_instructions_collect_unsigned_max_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.local_facts.unsigned_max_ready {
    return
  }
  for local_id = @ir.hot_local_param_count(func)
      local_id < @ir.hot_local_count(func)
      local_id = local_id + 1 {
    match @ir.hot_local_type(func, local_id) {
      Some(val_type) if val_type == @lib.ValType::i32() =>
        scratch.local_facts.i32_unsigned_max_by_local[local_id] = 0
      Some(val_type) if val_type == @lib.ValType::i64() =>
        scratch.local_facts.i64_unsigned_max_by_local[local_id] = 0L
      _ => ()
    }
  }
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    optimize_instructions_collect_unsigned_max_local_assignment_expr(
      func,
      dead,
      scratch,
      func.roots[slot],
    )
  }
  scratch.local_facts.unsigned_max_ready = true
}

///|
priv struct OiLiveNodeFact {
  live : Bool
}

///|
fn OiLiveNodeFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiLiveNodeFact {
  // Starshine keeps a pass-local dead bitset while mutating HOT. Route every
  // OI liveness guard through a fact so rewrite families share one boundary
  // for dead scratch ids, old HOT node slots, and freshly built live nodes.
  let live = if node_id < 0 {
    false
  } else if node_id < dead.length() {
    !dead[node_id]
  } else {
    @ir.hot_node_is_live(func, node_id)
  }
  { live, }
}

///|
fn OiLiveNodeFact::proves_live(self : OiLiveNodeFact) -> Bool {
  self.live
}

///|
fn OiLiveNodeFact::proves_node_live(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  OiLiveNodeFact::from_node(func, dead, node_id).proves_live()
}

///|
fn optimize_instructions_replace_with_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value : @lib.I32,
) -> Unit {
  let temp = @ir.hot_build_const_i32(func, value)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_const_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value : @lib.I64,
) -> Unit {
  let temp = @ir.hot_build_const_i64(func, value)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let temp = @ir.hot_build_unreachable(func)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_existing_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let replacement_id = @ir.hot_child_get(func, node_id, 0)
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement_id))
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_node_id(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  replacement_id : Int,
) -> Unit {
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement_id))
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_exact_unary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Unit {
  let result_ty = match instr {
    @lib.Instruction::I64Eqz => @lib.ValType::i32()
    @lib.Instruction::I64Extend8S
    | @lib.Instruction::I64Extend16S
    | @lib.Instruction::I64Extend32S => @lib.ValType::i64()
    _ => @lib.ValType::i32()
  }
  let temp = @ir.hot_build_unary(func, result_ty, operand_id)
  @ir.hot_node_exact_instr_set(func, temp, instr)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_exact_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Unit {
  let temp = @ir.hot_build_compare(func, lhs_id, rhs_id)
  @ir.hot_node_exact_instr_set(func, temp, instr)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
priv struct OiI32ValueFact {
  value_type : @lib.ValType?
}

///|
fn OiI32ValueFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiI32ValueFact {
  // Binaryen condition cleanup only erases compare-to-zero shells when the
  // exposed operand is an i32 condition value. Keep that result-type proof as
  // data instead of a freestanding helper predicate.
  let value_type = match
    @ir.hot_type_get(func, @ir.hot_node_get(func, node_id).ty) {
    @ir.HotTypeInfo::Value(val_type) => Some(val_type)
    _ => None
  }
  { value_type, }
}

///|
fn OiI32ValueFact::proves_i32_value(self : OiI32ValueFact) -> Bool {
  self.value_type == Some(@lib.ValType::i32())
}

///|
fn OiI32ValueFact::proves_node_i32_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  OiI32ValueFact::from_node(func, node_id).proves_i32_value()
}

///|
fn optimize_instructions_rewrite_exact_with_children(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  instr : @lib.Instruction,
  new_children : Array[Int],
) -> Unit {
  ignore(@ir.hot_replace_child_span(func, node_id, new_children))
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  pass_mark_mutated(ctx, func)
}

///|
priv struct OiCallRefFallthroughTargetFact {
  direct_func : Int
  ref_func_heap : @lib.HeapType?
}

///|
fn OiCallRefFallthroughTargetFact::unknown() -> OiCallRefFallthroughTargetFact {
  { direct_func: -1, ref_func_heap: None }
}

///|
priv struct OiCallRefIfFallthroughTargetFact {
  then_explicitly_stops : Bool
  else_explicitly_stops : Bool
  fallthrough_arm_id : Int
  arm_fact : OiCallRefFallthroughTargetFact
}

///|
priv struct OiCallRefLoopFallthroughTargetFact {
  body_id : Int
  body_fact : OiCallRefFallthroughTargetFact
}

///|
priv enum OiCallRefBrOnFallthroughTargetKind {
  CallRefBrOnNullFallthroughRef
  CallRefBrOnNonNullFallthroughRef
  CallRefBrOnCastFallthroughRef
  CallRefBrOnCastFailFallthroughRef
}

///|
priv struct OiCallRefBrOnFallthroughTargetFact {
  kind : OiCallRefBrOnFallthroughTargetKind
  branch_target_id : Int
  ref_id : Int
  ref_is_final_child : Bool
  ref_fact : OiCallRefFallthroughTargetFact
}

///|
fn OiCallRefFallthroughTargetFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  depth? : Int = 0,
) -> OiCallRefFallthroughTargetFact {
  if depth > 8 || !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return OiCallRefFallthroughTargetFact::unknown()
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::RefFunc => {
      let ref_func_heap = match
        optimize_instructions_node_ref_result_type(func, node_id) {
        Some(ref_type) => Some(ref_type.get_heap_type())
        None => None
      }
      { direct_func: node.imm0, ref_func_heap }
    }
    @ir.HotOp::LocalTee if node.child_count == 1 =>
      OiCallRefFallthroughTargetFact::from_node(
        func,
        dead,
        @ir.hot_child_get(func, node_id, 0),
        depth=depth + 1,
      )
    @ir.HotOp::Heap if node.child_count == 1 =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefAsNonNull) =>
          OiCallRefFallthroughTargetFact::from_node(
            func,
            dead,
            @ir.hot_child_get(func, node_id, 0),
            depth=depth + 1,
          )
        _ => OiCallRefFallthroughTargetFact::unknown()
      }
    @ir.HotOp::RefCast if node.child_count == 1 =>
      OiCallRefFallthroughTargetFact::from_node(
        func,
        dead,
        @ir.hot_child_get(func, node_id, 0),
        depth=depth + 1,
      )
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let root_count = @ir.hot_region_root_count(func, body_ref)
      if root_count < 1 {
        return OiCallRefFallthroughTargetFact::unknown()
      }
      OiCallRefFallthroughTargetFact::from_node(
        func,
        dead,
        @ir.hot_region_get(func, body_ref, root_count - 1),
        depth=depth + 1,
      )
    }
    @ir.HotOp::Loop =>
      match
        OiCallRefLoopFallthroughTargetFact::from_loop_target(
          func, dead, node_id, depth,
        ) {
        Some(fact) if fact.proves_ref_func_body_fallthrough() => fact.body_fact
        _ => OiCallRefFallthroughTargetFact::unknown()
      }
    @ir.HotOp::If =>
      match
        OiCallRefIfFallthroughTargetFact::from_if_target(
          func, dead, node_id, depth,
        ) {
        Some(fact) if fact.proves_one_sided_ref_func_fallthrough() =>
          fact.arm_fact
        _ => OiCallRefFallthroughTargetFact::unknown()
      }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      match
        OiCallRefBrOnFallthroughTargetFact::from_br_on_target(
          func, dead, node_id, depth,
        ) {
        Some(fact) if fact.proves_ref_func_ref_fallthrough() => fact.ref_fact
        _ => OiCallRefFallthroughTargetFact::unknown()
      }
    _ => OiCallRefFallthroughTargetFact::unknown()
  }
}

///|
fn OiCallRefBrOnFallthroughTargetFact::from_br_on_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  depth : Int,
) -> OiCallRefBrOnFallthroughTargetFact? {
  // Binaryen v130 `Properties::getImmediateFallthroughPtr` returns `BrOn::ref`
  // for every `br_on_*` target before `visitCallRef` checks for a `ref.func`.
  // Starshine's represented subset keeps the original branch target intact in
  // the later dropped evaluation, so this fact only proves that the explicit
  // reference child falls through to a direct function. It does not claim broad
  // branch retargeting, branch-value localization, EH, or multivalue repair.
  let node = @ir.hot_node_get(func, node_id)
  let kind = match node.op {
    @ir.HotOp::BrOnNull => CallRefBrOnNullFallthroughRef
    @ir.HotOp::BrOnNonNull => CallRefBrOnNonNullFallthroughRef
    @ir.HotOp::BrOnCast => CallRefBrOnCastFallthroughRef
    @ir.HotOp::BrOnCastFail => CallRefBrOnCastFailFallthroughRef
    _ => return None
  }
  if node.child_count < 1 {
    return None
  }
  let ref_slot = node.child_count - 1
  let ref_id = @ir.hot_child_get(func, node_id, ref_slot)
  if !OiLiveNodeFact::proves_node_live(func, dead, ref_id) {
    return None
  }
  let ref_fact = OiCallRefFallthroughTargetFact::from_node(
    func,
    dead,
    ref_id,
    depth=depth + 1,
  )
  Some({
    kind,
    branch_target_id: node.imm0,
    ref_id,
    ref_is_final_child: ref_slot == node.child_count - 1,
    ref_fact,
  })
}

///|
fn OiCallRefBrOnFallthroughTargetFact::proves_ref_func_ref_fallthrough(
  self : OiCallRefBrOnFallthroughTargetFact,
) -> Bool {
  let supported_br_on_kind = match self.kind {
    CallRefBrOnNullFallthroughRef
    | CallRefBrOnNonNullFallthroughRef
    | CallRefBrOnCastFallthroughRef
    | CallRefBrOnCastFailFallthroughRef => true
  }
  supported_br_on_kind &&
  self.branch_target_id >= 0 &&
  self.ref_id >= 0 &&
  self.ref_is_final_child &&
  self.ref_fact.has_direct_func()
}

///|
fn OiCallRefLoopFallthroughTargetFact::from_loop_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  depth : Int,
) -> OiCallRefLoopFallthroughTargetFact? {
  // Binaryen v130 `Properties::getImmediateFallthrough` descends from a loop
  // target to its body before `visitCallRef` asks whether the final fallthrough
  // is a `ref.func`. The represented safe subset keeps the whole loop target in
  // the later dropped evaluation and proves the explicit live tail root of the
  // loop body; branch/EH loop exits remain reopening criteria for a
  // ChildLocalizer/effect-aware loop fact.
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Loop => ()
    _ => return None
  }
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < 1 {
    return None
  }
  let body_id = @ir.hot_region_get(func, body_ref, root_count - 1)
  if !OiLiveNodeFact::proves_node_live(func, dead, body_id) {
    return None
  }
  let body_fact = OiCallRefFallthroughTargetFact::from_node(
    func,
    dead,
    body_id,
    depth=depth + 1,
  )
  Some({ body_id, body_fact })
}

///|
fn OiCallRefLoopFallthroughTargetFact::proves_ref_func_body_fallthrough(
  self : OiCallRefLoopFallthroughTargetFact,
) -> Bool {
  self.body_id >= 0 && self.body_fact.has_direct_func()
}

///|
fn OiCallRefIfFallthroughTargetFact::from_if_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  depth : Int,
) -> OiCallRefIfFallthroughTargetFact? {
  // Binaryen v130 `Properties::getImmediateFallthrough` descends through an
  // `if` only when exactly one arm is unreachable. `visitCallRef` still drops
  // the original target before the direct call, so this fact only proves which
  // arm supplies the target's fallthrough `ref.func`; it does not claim general
  // two-arm control localization or branch/EH/multivalue preservation.
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ => return None
  }
  let else_ref = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None => return None
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  let then_explicitly_stops = optimize_instructions_region_explicitly_does_not_fallthrough(
    func, then_ref,
  )
  let else_explicitly_stops = optimize_instructions_region_explicitly_does_not_fallthrough(
    func, else_ref,
  )
  let fallthrough_region = if then_explicitly_stops && !else_explicitly_stops {
    else_ref
  } else if else_explicitly_stops && !then_explicitly_stops {
    then_ref
  } else {
    return None
  }
  let fallthrough_arm_id = match
    optimize_instructions_region_tail_id(func, fallthrough_region) {
    Some(tail_id) if OiLiveNodeFact::proves_node_live(func, dead, tail_id) =>
      tail_id
    _ => return None
  }
  let arm_fact = OiCallRefFallthroughTargetFact::from_node(
    func,
    dead,
    fallthrough_arm_id,
    depth=depth + 1,
  )
  Some({
    then_explicitly_stops,
    else_explicitly_stops,
    fallthrough_arm_id,
    arm_fact,
  })
}

///|
fn OiCallRefIfFallthroughTargetFact::proves_one_sided_ref_func_fallthrough(
  self : OiCallRefIfFallthroughTargetFact,
) -> Bool {
  self.fallthrough_arm_id >= 0 &&
  self.arm_fact.has_direct_func() &&
  self.then_explicitly_stops != self.else_explicitly_stops
}

///|
fn OiCallRefFallthroughTargetFact::has_direct_func(
  self : OiCallRefFallthroughTargetFact,
) -> Bool {
  self.direct_func >= 0
}

///|
priv struct OiCallRefFallthroughTypeFact {
  target_heap : @lib.HeapType?
  fallthrough_heap : @lib.HeapType?
  heaps_match : Bool
}

///|
fn OiCallRefFallthroughTypeFact::from_target(
  func : @ir.HotFunc,
  target_id : Int,
  fallthrough : OiCallRefFallthroughTargetFact,
) -> OiCallRefFallthroughTypeFact {
  // Binaryen v130 `visitCallRef` accepts `getFallthrough(curr->target)` only
  // when `curr->target->type.getHeapType()` equals the fallthrough `ref.func`
  // heap. A cast can expose a `ref.func` fallthrough that would trap at runtime
  // because its static function type differs from the call_ref target type, so
  // keep that compatibility proof separate from the wrapper-descent fact.
  let target_heap = match
    optimize_instructions_node_ref_result_type(func, target_id) {
    Some(ref_type) => Some(ref_type.get_heap_type())
    None => None
  }
  let fallthrough_heap = fallthrough.ref_func_heap
  let heaps_match = match (target_heap, fallthrough_heap) {
    (Some(target), Some(fallthrough)) => target == fallthrough
    _ => false
  }
  { target_heap, fallthrough_heap, heaps_match }
}

///|
fn OiCallRefFallthroughTypeFact::proves_target_heap_matches_ref_func_heap(
  self : OiCallRefFallthroughTypeFact,
) -> Bool {
  ignore(self.target_heap)
  ignore(self.fallthrough_heap)
  self.heaps_match
}

///|
priv struct OiCallRefTargetSkipNonNullFact {
  replacement_target_id : Int
  skipped_non_null_cast : Bool
  child_static_ref_type : @lib.RefType?
  target_is_final_call_ref_child : Bool
}

///|
fn OiCallRefTargetSkipNonNullFact::from_call_ref_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  call_ref_id : Int,
) -> OiCallRefTargetSkipNonNullFact? {
  // Binaryen v130 `visitCallRef` runs `skipNonNullCast(curr->target, curr)`
  // before target directization. `skipNonNullCast` may remove a nullable
  // `ref.as_non_null` when doing so does not cross later sibling effects. For
  // call_ref / return_call_ref the target is the final child, so this fact can
  // prove that nullable-child skip without turning target classifiers into
  // wrapper scanners. Direct, table, fallthrough, select, and future
  // descriptor-producer facts all consume the same effective target.
  let call_ref = @ir.hot_node_get(func, call_ref_id)
  match call_ref.op {
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef => ()
    _ => return None
  }
  if call_ref.child_count < 1 {
    return None
  }
  let target_id = @ir.hot_child_get(func, call_ref_id, call_ref.child_count - 1)
  if !OiLiveNodeFact::proves_node_live(func, dead, target_id) {
    return None
  }
  let target = @ir.hot_node_get(func, target_id)
  match target.op {
    @ir.HotOp::Heap if target.child_count == 1 =>
      match @ir.hot_node_exact_instr(func, target_id) {
        Some(@lib.Instruction::RefAsNonNull) => {
          let child_id = @ir.hot_child_get(func, target_id, 0)
          if !OiLiveNodeFact::proves_node_live(func, dead, child_id) {
            return None
          }
          let child_static_ref_type = optimize_instructions_node_ref_result_type(
            func, child_id,
          )
          let target_is_final_call_ref_child = true
          match child_static_ref_type {
            Some(ref_type) if ref_type.is_non_nullable() ||
              target_is_final_call_ref_child =>
              Some({
                replacement_target_id: child_id,
                skipped_non_null_cast: true,
                child_static_ref_type,
                target_is_final_call_ref_child,
              })
            _ => None
          }
        }
        _ => None
      }
    _ => None
  }
}

///|
fn OiCallRefTargetSkipNonNullFact::proves_skip_preserves_order(
  self : OiCallRefTargetSkipNonNullFact,
) -> Bool {
  match self.child_static_ref_type {
    Some(ref_type) if ref_type.is_non_nullable() => true
    _ => self.target_is_final_call_ref_child
  }
}

///|
fn OiCallRefTargetSkipNonNullFact::effective_target_id(
  self : OiCallRefTargetSkipNonNullFact,
) -> Int {
  if self.skipped_non_null_cast && self.proves_skip_preserves_order() {
    self.replacement_target_id
  } else {
    -1
  }
}

///|
priv struct OiCallRefKnownNullTargetFact {
  target_id : Int
  fallthrough_null_id : Int
  target_effects_are_elidable : Bool
  target_effect_drop_id : Int
}

///|
fn OiCallRefKnownNullTargetFact::from_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  target_id : Int,
) -> OiCallRefKnownNullTargetFact? {
  // Binaryen v130 `trapOnNull` checks `getFallthrough(ref)->type.isNull()`
  // before replacing the parent with `getDroppedChildrenAndAppend(...,
  // unreachable)`. Keep that as target-slot evidence rather than folding every
  // wrapper into the call_ref directization classifier. The safe Starshine
  // subset here is a direct known-null leaf, a single-root block whose only
  // fallthrough root is that known-null leaf, or a branch-free multi-root block
  // whose fallthrough root is known-null and whose target effects can be
  // preserved by dropping the whole target block after the call_ref operands.
  // Broader control/EH fallthrough targets still need ChildLocalizer-style
  // ordered-effect support before this fact may preserve target-side effects.
  if target_id < 0 || !OiLiveNodeFact::proves_node_live(func, dead, target_id) {
    return None
  }
  let null_trap_fact = OiNullTrapFact::for_operand(
    func,
    target_id,
    traps_on_null=true,
  )
  if null_trap_fact.can_replace_parent_with_unreachable() {
    return Some({
      target_id,
      fallthrough_null_id: target_id,
      target_effects_are_elidable: true,
      target_effect_drop_id: -1,
    })
  }
  let target = @ir.hot_node_get(func, target_id)
  match target.op {
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, target_id)
      let root_count = @ir.hot_region_root_count(func, body_ref)
      if root_count < 1 {
        return None
      }
      let tail_id = @ir.hot_region_get(func, body_ref, root_count - 1)
      if !OiLiveNodeFact::proves_node_live(func, dead, tail_id) {
        return None
      }
      let tail_trap_fact = OiNullTrapFact::for_operand(
        func,
        tail_id,
        traps_on_null=true,
      )
      if !tail_trap_fact.can_replace_parent_with_unreachable() {
        return None
      }
      if root_count == 1 {
        return Some({
          target_id,
          fallthrough_null_id: tail_id,
          target_effects_are_elidable: true,
          target_effect_drop_id: -1,
        })
      }
      let branch_fact = OiDescriptorBranchControlFact::from_node(
        func, target_id, target_id,
      )
      if branch_fact.proves_has_branch_control() {
        return None
      }
      let target_results = @ir.hot_type_results(
        func,
        @ir.hot_node_type(func, target_id),
      )
      if target_results.length() != 1 {
        return None
      }
      if OiDescriptorInternalControlEffectFreeFact::from_node(
          func, dead, target_id, target_id,
        ).proves_effect_free_allowing_internal_control() {
        Some({
          target_id,
          fallthrough_null_id: tail_id,
          target_effects_are_elidable: true,
          target_effect_drop_id: -1,
        })
      } else {
        Some({
          target_id,
          fallthrough_null_id: tail_id,
          target_effects_are_elidable: false,
          target_effect_drop_id: target_id,
        })
      }
    }
    _ => None
  }
}

///|
fn OiCallRefKnownNullTargetFact::proves_elidable_known_null_fallthrough(
  self : OiCallRefKnownNullTargetFact,
) -> Bool {
  ignore(self.target_id)
  self.fallthrough_null_id >= 0 &&
  (self.target_effects_are_elidable || self.target_effect_drop_id >= 0)
}

///|
priv struct OiCallRefNullTrapPlanFact {
  target_fact : OiCallRefKnownNullTargetFact
  child_layout_fact : OiCallRefChildLayoutFact
}

///|
fn OiCallRefNullTrapPlanFact::from_child_layout(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  child_layout_fact : OiCallRefChildLayoutFact,
) -> OiCallRefNullTrapPlanFact? {
  // Binaryen v130 `visitCallRef` runs `skipNonNullCast(curr->target, curr)` and
  // then `trapOnNull(curr, curr->target)` before any direct/table/fallthrough
  // target classification. Consume the shared child-layout/effective-target
  // fact here so the null-trap path does not re-split call_ref operands or
  // duplicate the target-slot `skipNonNullCast` proof.
  if child_layout_fact.effective_target_id < 0 {
    return None
  }
  let target_fact = match
    OiCallRefKnownNullTargetFact::from_target(
      func,
      dead,
      child_layout_fact.effective_target_id,
    ) {
    Some(fact) if fact.proves_elidable_known_null_fallthrough() => fact
    _ => return None
  }
  Some({ target_fact, child_layout_fact })
}

///|
fn OiCallRefNullTrapPlanFact::apply(
  self : OiCallRefNullTrapPlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let body : Array[Int] = []
  if !optimize_instructions_append_ordered_effects(
      ctx,
      func,
      self.child_layout_fact.args,
      body,
    ) {
    return false
  }
  if self.target_fact.target_effect_drop_id >= 0 {
    body.push(@ir.hot_build_drop(func, self.target_fact.target_effect_drop_id))
  }
  if body.length() == 0 {
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
    return true
  }
  body.push(@ir.hot_build_unreachable(func))
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let replacement = @ir.hot_build_block(func, block_type, body)
  let replacement_node = @ir.hot_node_get(func, replacement)
  @ir.hot_replace_node(func, node_id, replacement_node)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
priv struct OiCallRefSelectTargetFact {
  same_func : Int
  true_func : Int
  false_func : Int
  condition_id : Int
  condition_has_effects : Bool
  residue_arm_id : Int
}

///|
priv struct OiCallRefDirectTargetFact {
  target_id : Int
  direct_func : Int
  ref_func_heap : @lib.HeapType?
}

///|
priv struct OiCallRefTableTargetFact {
  target_id : Int
  table_idx : Int
  table_index_id : Int
}

///|
priv struct OiCallRefFallthroughDirectTargetFact {
  target_id : Int
  fallthrough_func : Int
  fallthrough_fact : OiCallRefFallthroughTargetFact
  type_fact : OiCallRefFallthroughTypeFact
}

///|
priv enum OiCallRefTargetClassificationKind {
  CallRefTargetUnknown
  CallRefTargetDirectFunc
  CallRefTargetTableGet
  CallRefTargetFallthroughFunc
  CallRefTargetSelectDirectFuncs
}

///|
priv struct OiCallRefTargetClassificationFact {
  kind : OiCallRefTargetClassificationKind
  target_id : Int
  direct_fact : OiCallRefDirectTargetFact?
  table_fact : OiCallRefTableTargetFact?
  fallthrough_direct_fact : OiCallRefFallthroughDirectTargetFact?
  select_fact : OiCallRefSelectTargetFact?
}

///|
priv struct OiCallRefTargetFact {
  direct_func : Int
  table_idx : Int
  table_index_id : Int
  fallthrough_func : Int
  select_fact : OiCallRefSelectTargetFact?
  direct_fact : OiCallRefDirectTargetFact?
  table_fact : OiCallRefTableTargetFact?
  fallthrough_direct_fact : OiCallRefFallthroughDirectTargetFact?
}

///|
fn OiCallRefTargetFact::unknown() -> OiCallRefTargetFact {
  {
    direct_func: -1,
    table_idx: -1,
    table_index_id: -1,
    fallthrough_func: -1,
    select_fact: None,
    direct_fact: None,
    table_fact: None,
    fallthrough_direct_fact: None,
  }
}

///|
fn OiCallRefTargetFact::from_direct_fact(
  fact : OiCallRefDirectTargetFact,
) -> OiCallRefTargetFact {
  {
    direct_func: fact.direct_func,
    table_idx: -1,
    table_index_id: -1,
    fallthrough_func: -1,
    select_fact: None,
    direct_fact: Some(fact),
    table_fact: None,
    fallthrough_direct_fact: None,
  }
}

///|
fn OiCallRefTargetFact::from_table_fact(
  fact : OiCallRefTableTargetFact,
) -> OiCallRefTargetFact {
  {
    direct_func: -1,
    table_idx: fact.table_idx,
    table_index_id: fact.table_index_id,
    fallthrough_func: -1,
    select_fact: None,
    direct_fact: None,
    table_fact: Some(fact),
    fallthrough_direct_fact: None,
  }
}

///|
fn OiCallRefTargetFact::from_fallthrough_direct_fact(
  fact : OiCallRefFallthroughDirectTargetFact,
) -> OiCallRefTargetFact {
  {
    direct_func: -1,
    table_idx: -1,
    table_index_id: -1,
    fallthrough_func: fact.fallthrough_func,
    select_fact: None,
    direct_fact: None,
    table_fact: None,
    fallthrough_direct_fact: Some(fact),
  }
}

///|
fn OiCallRefTargetFact::from_select_fact(
  fact : OiCallRefSelectTargetFact,
) -> OiCallRefTargetFact {
  {
    direct_func: -1,
    table_idx: -1,
    table_index_id: -1,
    fallthrough_func: -1,
    select_fact: Some(fact),
    direct_fact: None,
    table_fact: None,
    fallthrough_direct_fact: None,
  }
}

///|
fn OiCallRefDirectTargetFact::from_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  target_id : Int,
) -> OiCallRefDirectTargetFact? {
  // Binaryen v130 `visitCallRef` handles immediate `RefFunc` targets before
  // the fallthrough and select paths. Keep the direct target classifier as its
  // own source-shaped fact so the generic call_ref plan consumes a proven
  // target rather than doing an opcode-local direct-call scan.
  if target_id < 0 || !OiLiveNodeFact::proves_node_live(func, dead, target_id) {
    return None
  }
  let target = @ir.hot_node_get(func, target_id)
  match target.op {
    @ir.HotOp::RefFunc => {
      let ref_func_heap = match
        optimize_instructions_node_ref_result_type(func, target_id) {
        Some(ref_type) => Some(ref_type.get_heap_type())
        None => None
      }
      Some({ target_id, direct_func: target.imm0, ref_func_heap })
    }
    _ => None
  }
}

///|
fn OiCallRefDirectTargetFact::proves_direct_ref_func(
  self : OiCallRefDirectTargetFact,
) -> Bool {
  ignore(self.ref_func_heap)
  self.target_id >= 0 && self.direct_func >= 0
}

///|
fn OiCallRefTableTargetFact::from_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  target_id : Int,
) -> OiCallRefTableTargetFact? {
  // Binaryen v130 `visitCallRef` handles immediate `TableGet` targets as the
  // table/index fact that lowers `call_ref` to `call_indirect`. Keep that fact
  // separate from direct, fallthrough, and select target facts so table lowering
  // is not an ad hoc branch inside the generic target classifier.
  if target_id < 0 || !OiLiveNodeFact::proves_node_live(func, dead, target_id) {
    return None
  }
  let target = @ir.hot_node_get(func, target_id)
  match target.op {
    @ir.HotOp::TableGet if target.child_count == 1 => {
      let table_index_id = @ir.hot_child_get(func, target_id, 0)
      if OiLiveNodeFact::proves_node_live(func, dead, table_index_id) {
        Some({ target_id, table_idx: target.imm0, table_index_id })
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn OiCallRefTableTargetFact::proves_table_get_target(
  self : OiCallRefTableTargetFact,
) -> Bool {
  self.target_id >= 0 && self.table_idx >= 0 && self.table_index_id >= 0
}

///|
fn OiCallRefFallthroughDirectTargetFact::from_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  target_id : Int,
) -> OiCallRefFallthroughDirectTargetFact? {
  // Binaryen v130 `visitCallRef` asks `Properties::getFallthrough` for a
  // `ref.func` after immediate direct/table targets fail, then checks that the
  // original call_ref target heap still matches the fallthrough function heap.
  // Keep that directizable-fallthrough proof as a source-shaped fact consumed
  // by the generic target plan, rather than branching on block/wrapper opcodes
  // in the target classifier.
  if target_id < 0 || !OiLiveNodeFact::proves_node_live(func, dead, target_id) {
    return None
  }
  let fallthrough_fact = OiCallRefFallthroughTargetFact::from_node(
    func, dead, target_id,
  )
  let type_fact = OiCallRefFallthroughTypeFact::from_target(
    func, target_id, fallthrough_fact,
  )
  if fallthrough_fact.has_direct_func() &&
    type_fact.proves_target_heap_matches_ref_func_heap() {
    Some({
      target_id,
      fallthrough_func: fallthrough_fact.direct_func,
      fallthrough_fact,
      type_fact,
    })
  } else {
    None
  }
}

///|
fn OiCallRefFallthroughDirectTargetFact::proves_fallthrough_ref_func(
  self : OiCallRefFallthroughDirectTargetFact,
) -> Bool {
  self.target_id >= 0 &&
  self.fallthrough_func >= 0 &&
  self.fallthrough_fact.has_direct_func() &&
  self.type_fact.proves_target_heap_matches_ref_func_heap()
}

///|
fn OiCallRefTargetClassificationFact::unknown(
  target_id : Int,
) -> OiCallRefTargetClassificationFact {
  {
    kind: CallRefTargetUnknown,
    target_id,
    direct_fact: None,
    table_fact: None,
    fallthrough_direct_fact: None,
    select_fact: None,
  }
}

///|
fn OiCallRefTargetClassificationFact::from_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  callee_ref_id : Int,
) -> OiCallRefTargetClassificationFact {
  // Binaryen v130 `visitCallRef` classifies targets in a fixed source order:
  // direct `ref.func`, immediate `table.get`, `Properties::getFallthrough`
  // direct `ref.func`, and finally the select/direct-call utility. Keep the
  // ordered classification as a fact so directization consumes one target
  // record instead of rebuilding the visitor's opcode cascade inline.
  if !OiLiveNodeFact::proves_node_live(func, dead, callee_ref_id) {
    return OiCallRefTargetClassificationFact::unknown(callee_ref_id)
  }
  let callee_ref = @ir.hot_node_get(func, callee_ref_id)
  match OiCallRefDirectTargetFact::from_target(func, dead, callee_ref_id) {
    Some(fact) if fact.proves_direct_ref_func() =>
      return {
        kind: CallRefTargetDirectFunc,
        target_id: callee_ref_id,
        direct_fact: Some(fact),
        table_fact: None,
        fallthrough_direct_fact: None,
        select_fact: None,
      }
    _ => ()
  }
  match OiCallRefTableTargetFact::from_target(func, dead, callee_ref_id) {
    Some(fact) if fact.proves_table_get_target() =>
      return {
        kind: CallRefTargetTableGet,
        target_id: callee_ref_id,
        direct_fact: None,
        table_fact: Some(fact),
        fallthrough_direct_fact: None,
        select_fact: None,
      }
    _ => ()
  }
  match
    OiCallRefFallthroughDirectTargetFact::from_target(func, dead, callee_ref_id) {
    Some(fact) if fact.proves_fallthrough_ref_func() =>
      return {
        kind: CallRefTargetFallthroughFunc,
        target_id: callee_ref_id,
        direct_fact: None,
        table_fact: None,
        fallthrough_direct_fact: Some(fact),
        select_fact: None,
      }
    _ => ()
  }
  match callee_ref.op {
    @ir.HotOp::Select if callee_ref.child_count == 3 =>
      match OiCallRefSelectTargetFact::from_select(func, dead, callee_ref_id) {
        Some(fact) =>
          {
            kind: CallRefTargetSelectDirectFuncs,
            target_id: callee_ref_id,
            direct_fact: None,
            table_fact: None,
            fallthrough_direct_fact: None,
            select_fact: Some(fact),
          }
        None => OiCallRefTargetClassificationFact::unknown(callee_ref_id)
      }
    _ => OiCallRefTargetClassificationFact::unknown(callee_ref_id)
  }
}

///|
fn OiCallRefTargetClassificationFact::target_fact(
  self : OiCallRefTargetClassificationFact,
) -> OiCallRefTargetFact {
  ignore(self.target_id)
  match self.kind {
    CallRefTargetDirectFunc =>
      match self.direct_fact {
        Some(fact) => OiCallRefTargetFact::from_direct_fact(fact)
        None => OiCallRefTargetFact::unknown()
      }
    CallRefTargetTableGet =>
      match self.table_fact {
        Some(fact) => OiCallRefTargetFact::from_table_fact(fact)
        None => OiCallRefTargetFact::unknown()
      }
    CallRefTargetFallthroughFunc =>
      match self.fallthrough_direct_fact {
        Some(fact) => OiCallRefTargetFact::from_fallthrough_direct_fact(fact)
        None => OiCallRefTargetFact::unknown()
      }
    CallRefTargetSelectDirectFuncs =>
      match self.select_fact {
        Some(fact) => OiCallRefTargetFact::from_select_fact(fact)
        None => OiCallRefTargetFact::unknown()
      }
    CallRefTargetUnknown => OiCallRefTargetFact::unknown()
  }
}

///|
priv struct OiCallRefSelectArmFact {
  direct_func : Int
  ref_func_heap : @lib.HeapType?
  elided_non_null_wrapper_depth : Int
  elided_cast_wrapper_depth : Int
}

///|
fn OiCallRefSelectArmFact::unknown() -> OiCallRefSelectArmFact {
  {
    direct_func: -1,
    ref_func_heap: None,
    elided_non_null_wrapper_depth: 0,
    elided_cast_wrapper_depth: 0,
  }
}

///|
fn OiCallRefSelectArmFact::direct(
  direct_func : Int,
  ref_func_heap : @lib.HeapType?,
  elided_non_null_wrapper_depth? : Int = 0,
  elided_cast_wrapper_depth? : Int = 0,
) -> OiCallRefSelectArmFact {
  {
    direct_func,
    ref_func_heap,
    elided_non_null_wrapper_depth,
    elided_cast_wrapper_depth,
  }
}

///|
priv struct OiCallRefSelectArmCastFact {
  child_fact : OiCallRefSelectArmFact
  ref_func_heap : @lib.HeapType?
  heaps_match : Bool
}

///|
fn OiCallRefSelectArmCastFact::from_cast_arm(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  arm_id : Int,
  depth : Int,
) -> OiCallRefSelectArmCastFact? {
  let arm = @ir.hot_node_get(func, arm_id)
  match arm.op {
    @ir.HotOp::RefCast if arm.child_count == 1 => ()
    _ => return None
  }
  let cast_heap = match @ir.hot_node_exact_instr(func, arm_id) {
    Some(@lib.Instruction::RefCast(_, _, heap)) => heap
    _ => return None
  }
  let child_fact = OiCallRefSelectArmFact::from_target_arm(
    func,
    dead,
    @ir.hot_child_get(func, arm_id, 0),
    depth=depth + 1,
  )
  if !child_fact.has_direct_func() {
    return None
  }
  let heaps_match = match child_fact.ref_func_heap {
    Some(ref_func_heap) => ref_func_heap == cast_heap
    None => false
  }
  Some({ child_fact, ref_func_heap: child_fact.ref_func_heap, heaps_match })
}

///|
fn OiCallRefSelectArmCastFact::proves_known_success(
  self : OiCallRefSelectArmCastFact,
) -> Bool {
  self.heaps_match
}

///|
fn OiCallRefSelectArmFact::from_target_arm(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  arm_id : Int,
  depth? : Int = 0,
) -> OiCallRefSelectArmFact {
  if depth > 4 || !OiLiveNodeFact::proves_node_live(func, dead, arm_id) {
    return OiCallRefSelectArmFact::unknown()
  }
  let arm = @ir.hot_node_get(func, arm_id)
  match arm.op {
    // Binaryen v130 `OptimizeInstructions::visitCallRef` passes
    // `CallUtils::convertToDirectCalls` a classifier whose known target is a
    // direct `RefFunc` after child OI visitors have already removed no-op
    // `ref.as_non_null` wrappers around direct `ref.func` producers. Keep
    // effectful fallthrough arms such as
    // `local.tee(ref.func)` out of this fact until a source-backed
    // ChildLocalizer fact can preserve arm-side effects.
    @ir.HotOp::RefFunc => {
      let ref_func_heap = match
        optimize_instructions_node_ref_result_type(func, arm_id) {
        Some(ref_type) => Some(ref_type.get_heap_type())
        None => None
      }
      OiCallRefSelectArmFact::direct(arm.imm0, ref_func_heap)
    }
    @ir.HotOp::Heap if arm.child_count == 1 =>
      match @ir.hot_node_exact_instr(func, arm_id) {
        Some(@lib.Instruction::RefAsNonNull) => {
          let child_id = @ir.hot_child_get(func, arm_id, 0)
          let child_fact = OiCallRefSelectArmFact::from_target_arm(
            func,
            dead,
            child_id,
            depth=depth + 1,
          )
          if child_fact.has_direct_func() {
            OiCallRefSelectArmFact::direct(
              child_fact.direct_func,
              child_fact.ref_func_heap,
              elided_non_null_wrapper_depth=child_fact.elided_non_null_wrapper_depth +
                1,
              elided_cast_wrapper_depth=child_fact.elided_cast_wrapper_depth,
            )
          } else {
            OiCallRefSelectArmFact::unknown()
          }
        }
        _ => OiCallRefSelectArmFact::unknown()
      }
    @ir.HotOp::RefCast =>
      match
        OiCallRefSelectArmCastFact::from_cast_arm(func, dead, arm_id, depth) {
        Some(cast_fact) if cast_fact.proves_known_success() =>
          OiCallRefSelectArmFact::direct(
            cast_fact.child_fact.direct_func,
            cast_fact.ref_func_heap,
            elided_non_null_wrapper_depth=cast_fact.child_fact.elided_non_null_wrapper_depth,
            elided_cast_wrapper_depth=cast_fact.child_fact.elided_cast_wrapper_depth +
              1,
          )
        _ => OiCallRefSelectArmFact::unknown()
      }
    _ => OiCallRefSelectArmFact::unknown()
  }
}

///|
fn OiCallRefSelectArmFact::has_direct_func(
  self : OiCallRefSelectArmFact,
) -> Bool {
  self.direct_func >= 0
}

///|
priv struct OiCallRefSelectConditionFact {
  condition_id : Int
  has_effects : Bool
}

///|
fn OiCallRefSelectConditionFact::from_select_condition(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  condition_id : Int,
) -> OiCallRefSelectConditionFact? {
  if !OiLiveNodeFact::proves_node_live(func, dead, condition_id) {
    return None
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, condition_id)) {
    [condition_type] if condition_type == @lib.ValType::i32() =>
      Some({
        condition_id,
        has_effects: !OiSideEffectFreeExpressionFact::proves_node_free(
          func, dead, condition_id,
        ),
      })
    _ => None
  }
}

///|
fn OiCallRefSelectConditionFact::from_recorded_condition(
  func : @ir.HotFunc,
  condition_id : Int,
  has_effects : Bool,
) -> OiCallRefSelectConditionFact? {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, condition_id)) {
    [condition_type] if condition_type == @lib.ValType::i32() =>
      Some({ condition_id, has_effects })
    _ => None
  }
}

///|
fn OiCallRefSelectTargetFact::from_direct_arms(
  condition_fact : OiCallRefSelectConditionFact,
  true_fact : OiCallRefSelectArmFact,
  false_fact : OiCallRefSelectArmFact,
  residue_arm_id : Int,
) -> OiCallRefSelectTargetFact? {
  // Binaryen v130 `CallUtils::convertToDirectCalls` first classifies both
  // select arms as known direct targets, then either emits a one-call residue
  // for identical functions or an if-over-direct-calls for different functions.
  // Keep that select-specific target state together instead of spreading the
  // arm ids, same-target proof, and condition effect proof across the generic
  // call_ref target fact.
  if !true_fact.has_direct_func() || !false_fact.has_direct_func() {
    return None
  }
  let same_func = if true_fact.direct_func == false_fact.direct_func {
    true_fact.direct_func
  } else {
    -1
  }
  Some({
    same_func,
    true_func: true_fact.direct_func,
    false_func: false_fact.direct_func,
    condition_id: condition_fact.condition_id,
    condition_has_effects: condition_fact.has_effects,
    residue_arm_id,
  })
}

///|
fn OiCallRefSelectTargetFact::has_same_direct_func(
  self : OiCallRefSelectTargetFact,
) -> Bool {
  self.same_func >= 0 && self.condition_id >= 0
}

///|
fn OiCallRefSelectTargetFact::has_direct_funcs(
  self : OiCallRefSelectTargetFact,
) -> Bool {
  self.true_func >= 0 && self.false_func >= 0 && self.condition_id >= 0
}

///|
fn OiCallRefSelectTargetFact::condition_fact(
  self : OiCallRefSelectTargetFact,
  func : @ir.HotFunc,
) -> OiCallRefSelectConditionFact? {
  OiCallRefSelectConditionFact::from_recorded_condition(
    func,
    self.condition_id,
    self.condition_has_effects,
  )
}

///|
fn OiCallRefSelectTargetFact::from_select(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  callee_ref_id : Int,
) -> OiCallRefSelectTargetFact? {
  // Binaryen v130 delegates select target directization to
  // `CallUtils::convertToDirectCalls` after direct/table/fallthrough targets
  // have failed. This select fact owns the three child slots and the arm/condition
  // classification before the outer target-classification fact records the
  // select as one ordered target family.
  let true_ref_id = @ir.hot_child_get(func, callee_ref_id, 0)
  let false_ref_id = @ir.hot_child_get(func, callee_ref_id, 1)
  let condition_id = @ir.hot_child_get(func, callee_ref_id, 2)
  let condition_fact = match
    OiCallRefSelectConditionFact::from_select_condition(
      func, dead, condition_id,
    ) {
    Some(fact) => fact
    None => return None
  }
  let true_fact = OiCallRefSelectArmFact::from_target_arm(
    func, dead, true_ref_id,
  )
  let false_fact = OiCallRefSelectArmFact::from_target_arm(
    func, dead, false_ref_id,
  )
  OiCallRefSelectTargetFact::from_direct_arms(
    condition_fact, true_fact, false_fact, true_ref_id,
  )
}

///|
fn OiCallRefTargetFact::has_direct_func(self : OiCallRefTargetFact) -> Bool {
  match self.direct_fact {
    Some(fact) => fact.proves_direct_ref_func()
    None => self.direct_func >= 0
  }
}

///|
fn OiCallRefTargetFact::has_table_target(self : OiCallRefTargetFact) -> Bool {
  match self.table_fact {
    Some(fact) => fact.proves_table_get_target()
    None => self.table_idx >= 0 && self.table_index_id >= 0
  }
}

///|
fn OiCallRefTargetFact::has_fallthrough_func(
  self : OiCallRefTargetFact,
) -> Bool {
  match self.fallthrough_direct_fact {
    Some(fact) => fact.proves_fallthrough_ref_func()
    None => self.fallthrough_func >= 0
  }
}

///|
fn OiCallRefTargetFact::has_select_same_direct_func(
  self : OiCallRefTargetFact,
) -> Bool {
  match self.select_fact {
    Some(fact) => fact.has_same_direct_func()
    None => false
  }
}

///|
fn OiCallRefTargetFact::has_select_direct_funcs(
  self : OiCallRefTargetFact,
) -> Bool {
  match self.select_fact {
    Some(fact) => fact.has_direct_funcs()
    None => false
  }
}

///|
priv struct OiCallRefOperandFact {
  args : Array[Int]
  arg_types : Array[@lib.ValType]
}

///|
priv struct OiCallRefLocalizedOperandFact {
  prefix : Array[Int]
  local_ids : Array[Int]
}

///|
priv struct OiCallRefFallthroughOperandInterpositionFact {
  args : Array[Int]
  arg_types : Array[@lib.ValType]
  callee_ref_id : Int
}

///|
priv struct OiCallRefSelectResidueOperandInterpositionFact {
  args : Array[Int]
  arg_types : Array[@lib.ValType]
  residue_fact : OiCallRefSelectTargetResidueFact
}

///|
fn OiCallRefOperandFact::from_args(
  func : @ir.HotFunc,
  args : Array[Int],
) -> OiCallRefOperandFact? {
  let fact_args : Array[Int] = []
  let arg_types : Array[@lib.ValType] = []
  for arg in args {
    let arg_node = @ir.hot_node_get(func, arg)
    let arg_results = @ir.hot_type_results(func, arg_node.ty)
    if arg_results.length() != 1 {
      return None
    }
    fact_args.push(arg)
    arg_types.push(arg_results[0])
  }
  Some({ args: fact_args, arg_types })
}

///|
fn OiCallRefOperandFact::localize_all(
  self : OiCallRefOperandFact,
  func : @ir.HotFunc,
) -> OiCallRefLocalizedOperandFact {
  let prefix : Array[Int] = []
  let local_ids : Array[Int] = []
  for i = 0; i < self.args.length(); i = i + 1 {
    let local_id = @ir.hot_append_body_local(func, self.arg_types[i])
    prefix.push(@ir.hot_build_local_set(func, local_id, self.args[i]))
    local_ids.push(local_id)
  }
  { prefix, local_ids }
}

///|
fn OiCallRefLocalizedOperandFact::local_gets(
  self : OiCallRefLocalizedOperandFact,
  func : @ir.HotFunc,
) -> Array[Int] {
  let gets : Array[Int] = []
  for local_id in self.local_ids {
    gets.push(@ir.hot_build_local_get(func, local_id))
  }
  gets
}

///|
fn OiCallRefFallthroughOperandInterpositionFact::from_operand_fact(
  operand_fact : OiCallRefOperandFact,
  callee_ref_id : Int,
) -> OiCallRefFallthroughOperandInterpositionFact? {
  // Binaryen v130 fallthrough-target directization preserves call_ref operand
  // order by interposing the original target evaluation after the last operand:
  // `set(last); drop(target); get(last)`. Keep that last-operand proof as an
  // explicit operand fact instead of open-coding it in the directization plan.
  if callee_ref_id < 0 {
    return None
  }
  Some({
    args: operand_fact.args,
    arg_types: operand_fact.arg_types,
    callee_ref_id,
  })
}

///|
fn OiCallRefFallthroughOperandInterpositionFact::build_args(
  self : OiCallRefFallthroughOperandInterpositionFact,
  func : @ir.HotFunc,
) -> Array[Int]? {
  let arg_count = self.args.length()
  if arg_count == 0 {
    return Some([])
  }
  let last_index = arg_count - 1
  let operands : Array[Int] = []
  for i = 0; i < last_index; i = i + 1 {
    operands.push(self.args[i])
  }
  let temp_local = @ir.hot_append_body_local(func, self.arg_types[last_index])
  operands.push(
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(self.arg_types[last_index]),
      [
        @ir.hot_build_local_set(func, temp_local, self.args[last_index]),
        @ir.hot_build_drop(func, self.callee_ref_id),
        @ir.hot_build_local_get(func, temp_local),
      ],
    ),
  )
  Some(operands)
}

///|
fn OiCallRefOperandFact::args_with_fallthrough_target_after_last_operand(
  self : OiCallRefOperandFact,
  func : @ir.HotFunc,
  callee_ref_id : Int,
) -> Array[Int]? {
  match
    OiCallRefFallthroughOperandInterpositionFact::from_operand_fact(
      self, callee_ref_id,
    ) {
    Some(fact) => fact.build_args(func)
    None => None
  }
}

///|
fn OiCallRefSelectResidueOperandInterpositionFact::from_operand_fact(
  operand_fact : OiCallRefOperandFact,
  residue_fact : OiCallRefSelectTargetResidueFact,
) -> OiCallRefSelectResidueOperandInterpositionFact? {
  // Binaryen v130 collapses same-target select call_ref producers to a single
  // direct call but keeps the effectful select target evaluation in the original
  // target slot: after ordinary call_ref operands and before the direct call.
  // `OiCallRefSelectTargetResidueFact` owns that target residue; this fact owns
  // the matching last-operand interposition rule.
  Some({
    args: operand_fact.args,
    arg_types: operand_fact.arg_types,
    residue_fact,
  })
}

///|
fn OiCallRefSelectResidueOperandInterpositionFact::build_args(
  self : OiCallRefSelectResidueOperandInterpositionFact,
  func : @ir.HotFunc,
) -> Array[Int]? {
  if !self.residue_fact.has_effects() {
    return Some(self.args.copy())
  }
  let arg_count = self.args.length()
  if arg_count == 0 {
    return Some([])
  }
  let last_index = arg_count - 1
  let operands : Array[Int] = []
  for i = 0; i < last_index; i = i + 1 {
    operands.push(self.args[i])
  }
  let temp_local = @ir.hot_append_body_local(func, self.arg_types[last_index])
  operands.push(
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(self.arg_types[last_index]),
      [
        @ir.hot_build_local_set(func, temp_local, self.args[last_index]),
        self.residue_fact.build_dropped_target_evaluation(func),
        @ir.hot_build_local_get(func, temp_local),
      ],
    ),
  )
  Some(operands)
}

///|
fn OiCallRefOperandFact::args_with_select_condition_after_last_operand(
  self : OiCallRefOperandFact,
  func : @ir.HotFunc,
  residue_fact : OiCallRefSelectTargetResidueFact,
) -> Array[Int]? {
  match
    OiCallRefSelectResidueOperandInterpositionFact::from_operand_fact(
      self, residue_fact,
    ) {
    Some(fact) => fact.build_args(func)
    None => None
  }
}

///|
priv struct OiCallRefSelectTargetResidueFact {
  target_arm_id : Int
  target_type : @lib.ValType
  condition_fact : OiCallRefSelectConditionFact
}

///|
fn OiCallRefSelectTargetResidueFact::from_same_target(
  func : @ir.HotFunc,
  callee_ref_id : Int,
  target_fact : OiCallRefTargetFact,
) -> OiCallRefSelectTargetResidueFact? {
  let select_fact = match target_fact.select_fact {
    Some(fact) if fact.has_same_direct_func() => fact
    _ => return None
  }
  let condition_fact = match select_fact.condition_fact(func) {
    Some(fact) => fact
    None => return None
  }
  if select_fact.residue_arm_id < 0 {
    return None
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, callee_ref_id)) {
    [target_type] =>
      Some({
        target_arm_id: select_fact.residue_arm_id,
        target_type,
        condition_fact,
      })
    _ => None
  }
}

///|
fn OiCallRefSelectTargetResidueFact::has_effects(
  self : OiCallRefSelectTargetResidueFact,
) -> Bool {
  self.condition_fact.has_effects
}

///|
fn OiCallRefSelectTargetResidueFact::build_dropped_target_evaluation(
  self : OiCallRefSelectTargetResidueFact,
  func : @ir.HotFunc,
) -> Int {
  // This mirrors the Binaryen v130 `CallUtils::convertToDirectCalls` residue for
  // identical select arms: the i32 condition is dropped for effects, then a
  // fact-proven target arm is materialized as the block result and the whole
  // target evaluation is dropped before the direct call.
  @ir.hot_build_drop(
    func,
    @ir.hot_build_block(func, @lib.BlockType::val_type(self.target_type), [
      @ir.hot_build_drop(func, self.condition_fact.condition_id),
      self.target_arm_id,
    ]),
  )
}

///|
priv struct OiCallRefResultBlockTypeFact {
  result_count : Int
  block_type : @lib.BlockType?
}

///|
fn OiCallRefResultBlockTypeFact::from_call_ref(
  func : @ir.HotFunc,
  node : @ir.HotNode,
) -> OiCallRefResultBlockTypeFact {
  // Binaryen v130 `visitCallRef` rebuilds directized `call_ref` replacements
  // with `curr->type`. Starshine's HOT builder needs the equivalent block
  // wrapper type only for fallthrough/select residue cases that must sequence a
  // dropped target before the direct call. Keep the single-result/multivalue
  // boundary as a fact instead of a generic helper hidden in replacement code.
  let results = @ir.hot_type_results(func, node.ty)
  let block_type = match results.length() {
    0 => Some(@lib.BlockType::void_())
    1 => Some(@lib.BlockType::val_type(results[0]))
    _ => None
  }
  { result_count: results.length(), block_type }
}

///|
fn OiCallRefResultBlockTypeFact::proves_representable_block_type(
  self : OiCallRefResultBlockTypeFact,
) -> Bool {
  self.result_count <= 1
}

///|
fn OiCallRefResultBlockTypeFact::representable_block_type(
  self : OiCallRefResultBlockTypeFact,
) -> @lib.BlockType? {
  match self.block_type {
    Some(block_type) =>
      if self.proves_representable_block_type() {
        Some(block_type)
      } else {
        None
      }
    None => None
  }
}

///|
priv enum OiCallRefDirectizePlanKind {
  CallRefDirectFunc
  CallRefTableTarget
  CallRefFallthroughFunc
  CallRefSelectSameDirectFunc
  CallRefSelectDirectFuncs
}

///|
priv struct OiCallRefDirectizePlanFact {
  kind : OiCallRefDirectizePlanKind
  target_fact : OiCallRefTargetFact
  operand_fact : OiCallRefOperandFact?
}

///|
fn OiCallRefDirectizePlanFact::from_target(
  func : @ir.HotFunc,
  target_fact : OiCallRefTargetFact,
  args : Array[Int],
) -> OiCallRefDirectizePlanFact? {
  // Binaryen v130 `visitCallRef` routes direct targets, typed-table targets,
  // fallthrough `ref.func` producers, and two-direct-arm selects through
  // `CallUtils::convertToDirectCalls`. Keep that routing as an explicit plan
  // fact so operand localization and call/return-call emission do not live in
  // an ad hoc branch cascade inside the pass visitor.
  if target_fact.has_direct_func() {
    return Some({ kind: CallRefDirectFunc, target_fact, operand_fact: None })
  }
  if target_fact.has_table_target() {
    return Some({ kind: CallRefTableTarget, target_fact, operand_fact: None })
  }
  if target_fact.has_fallthrough_func() {
    let operand_fact = match OiCallRefOperandFact::from_args(func, args) {
      Some(fact) => fact
      None => return None
    }
    return Some({
      kind: CallRefFallthroughFunc,
      target_fact,
      operand_fact: Some(operand_fact),
    })
  }
  if target_fact.has_select_same_direct_func() {
    let operand_fact = match OiCallRefOperandFact::from_args(func, args) {
      Some(fact) => fact
      None => return None
    }
    return Some({
      kind: CallRefSelectSameDirectFunc,
      target_fact,
      operand_fact: Some(operand_fact),
    })
  }
  if target_fact.has_select_direct_funcs() {
    let operand_fact = match OiCallRefOperandFact::from_args(func, args) {
      Some(fact) => fact
      None => return None
    }
    return Some({
      kind: CallRefSelectDirectFuncs,
      target_fact,
      operand_fact: Some(operand_fact),
    })
  }
  None
}

///|
fn OiCallRefDirectizePlanFact::operand_fact(
  self : OiCallRefDirectizePlanFact,
) -> OiCallRefOperandFact? {
  self.operand_fact
}

///|
fn OiCallRefDirectizePlanFact::build_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  callee_ref_id : Int,
  args : Array[Int],
) -> Int? {
  match self.kind {
    CallRefDirectFunc => self.build_direct_func_replacement(func, node, args)
    CallRefTableTarget => self.build_table_target_replacement(func, node, args)
    CallRefFallthroughFunc => {
      let operand_fact = match self.operand_fact() {
        Some(fact) => fact
        None => return None
      }
      self.build_fallthrough_func_replacement(
        func, node, callee_ref_id, operand_fact,
      )
    }
    CallRefSelectSameDirectFunc => {
      let operand_fact = match self.operand_fact() {
        Some(fact) => fact
        None => return None
      }
      self.build_select_same_direct_func_replacement(
        func, node, callee_ref_id, operand_fact,
      )
    }
    CallRefSelectDirectFuncs => {
      let operand_fact = match self.operand_fact() {
        Some(fact) => fact
        None => return None
      }
      self.build_select_direct_funcs_replacement(func, node, operand_fact)
    }
  }
}

///|
fn OiCallRefDirectizePlanFact::build_fallthrough_func_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  callee_ref_id : Int,
  operand_fact : OiCallRefOperandFact,
) -> Int? {
  if !self.target_fact.has_fallthrough_func() {
    return None
  }
  match node.op {
    @ir.HotOp::CallRef => {
      let result_type_fact = OiCallRefResultBlockTypeFact::from_call_ref(
        func, node,
      )
      let block_type = match result_type_fact.representable_block_type() {
        Some(block_type) => block_type
        None => return None
      }
      let results = @ir.hot_type_results(func, node.ty)
      match
        operand_fact.args_with_fallthrough_target_after_last_operand(
          func, callee_ref_id,
        ) {
        Some([]) =>
          Some(
            @ir.hot_build_block(func, block_type, [
              @ir.hot_build_drop(func, callee_ref_id),
              @ir.hot_build_call(
                func,
                self.target_fact.fallthrough_func,
                results,
                [],
              ),
            ]),
          )
        Some(operands) =>
          Some(
            @ir.hot_build_call(
              func,
              self.target_fact.fallthrough_func,
              results,
              operands,
            ),
          )
        None => None
      }
    }
    @ir.HotOp::ReturnCallRef =>
      match
        operand_fact.args_with_fallthrough_target_after_last_operand(
          func, callee_ref_id,
        ) {
        Some([]) =>
          Some(
            @ir.hot_build_block(func, @lib.BlockType::void_(), [
              @ir.hot_build_drop(func, callee_ref_id),
              @ir.hot_build_return_call(
                func,
                self.target_fact.fallthrough_func,
                [],
              ),
            ]),
          )
        Some(operands) =>
          Some(
            @ir.hot_build_return_call(
              func,
              self.target_fact.fallthrough_func,
              operands,
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
fn OiCallRefDirectizePlanFact::build_direct_func_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  args : Array[Int],
) -> Int? {
  match node.op {
    @ir.HotOp::CallRef =>
      Some(
        @ir.hot_build_call(
          func,
          self.target_fact.direct_func,
          @ir.hot_type_results(func, node.ty),
          args,
        ),
      )
    @ir.HotOp::ReturnCallRef =>
      Some(@ir.hot_build_return_call(func, self.target_fact.direct_func, args))
    _ => None
  }
}

///|
fn OiCallRefDirectizePlanFact::build_table_target_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  args : Array[Int],
) -> Int? {
  let sig = @ir.hot_call_sig_get(func, node.imm0)
  match node.op {
    @ir.HotOp::CallRef =>
      Some(
        @ir.hot_build_call_indirect(
          func,
          sig.type_idx,
          @lib.TableIdx::new(self.target_fact.table_idx.reinterpret_as_uint()),
          @ir.hot_type_results(func, node.ty),
          args,
          self.target_fact.table_index_id,
        ),
      )
    @ir.HotOp::ReturnCallRef =>
      Some(
        @ir.hot_build_return_call_indirect(
          func,
          sig.type_idx,
          @lib.TableIdx::new(self.target_fact.table_idx.reinterpret_as_uint()),
          args,
          self.target_fact.table_index_id,
        ),
      )
    _ => None
  }
}

///|
fn OiCallRefDirectizePlanFact::build_select_same_direct_func_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  callee_ref_id : Int,
  operand_fact : OiCallRefOperandFact,
) -> Int? {
  let select_fact = match self.target_fact.select_fact {
    Some(fact) if fact.has_same_direct_func() => fact
    _ => return None
  }
  let residue_fact = match
    OiCallRefSelectTargetResidueFact::from_same_target(
      func,
      callee_ref_id,
      self.target_fact,
    ) {
    Some(fact) => fact
    None => return None
  }
  let results = @ir.hot_type_results(func, node.ty)
  let operands = match
    operand_fact.args_with_select_condition_after_last_operand(
      func, residue_fact,
    ) {
    Some(operands) => operands
    None => return None
  }
  match node.op {
    @ir.HotOp::CallRef => {
      let direct_call = @ir.hot_build_call(
        func,
        select_fact.same_func,
        results,
        operands,
      )
      if residue_fact.has_effects() && operand_fact.args.length() == 0 {
        let result_type_fact = OiCallRefResultBlockTypeFact::from_call_ref(
          func, node,
        )
        let block_type = match result_type_fact.representable_block_type() {
          Some(block_type) => block_type
          None => return None
        }
        Some(
          @ir.hot_build_block(func, block_type, [
            residue_fact.build_dropped_target_evaluation(func),
            direct_call,
          ]),
        )
      } else {
        Some(direct_call)
      }
    }
    @ir.HotOp::ReturnCallRef => {
      let direct_call = @ir.hot_build_return_call(
        func,
        select_fact.same_func,
        operands,
      )
      if residue_fact.has_effects() && operand_fact.args.length() == 0 {
        Some(
          @ir.hot_build_block(func, @lib.BlockType::void_(), [
            residue_fact.build_dropped_target_evaluation(func),
            direct_call,
          ]),
        )
      } else {
        Some(direct_call)
      }
    }
    _ => None
  }
}

///|
fn OiCallRefDirectizePlanFact::build_select_direct_funcs_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  operand_fact : OiCallRefOperandFact,
) -> Int? {
  let select_fact = match self.target_fact.select_fact {
    Some(fact) if fact.has_direct_funcs() => fact
    _ => return None
  }
  let block_type = match node.op {
    @ir.HotOp::CallRef => {
      let result_type_fact = OiCallRefResultBlockTypeFact::from_call_ref(
        func, node,
      )
      match result_type_fact.representable_block_type() {
        Some(block_type) => block_type
        None => return None
      }
    }
    @ir.HotOp::ReturnCallRef => @lib.BlockType::void_()
    _ => return None
  }
  let localized_operands = operand_fact.localize_all(func)
  let replacement_if = match node.op {
    @ir.HotOp::CallRef =>
      @ir.hot_build_if(
        func,
        block_type,
        select_fact.condition_id,
        [
          @ir.hot_build_call(
            func,
            select_fact.true_func,
            @ir.hot_type_results(func, node.ty),
            localized_operands.local_gets(func),
          ),
        ],
        else_body=Some([
          @ir.hot_build_call(
            func,
            select_fact.false_func,
            @ir.hot_type_results(func, node.ty),
            localized_operands.local_gets(func),
          ),
        ]),
      )
    @ir.HotOp::ReturnCallRef =>
      @ir.hot_build_if(
        func,
        @lib.BlockType::void_(),
        select_fact.condition_id,
        [
          @ir.hot_build_return_call(
            func,
            select_fact.true_func,
            localized_operands.local_gets(func),
          ),
        ],
        else_body=Some([
          @ir.hot_build_return_call(
            func,
            select_fact.false_func,
            localized_operands.local_gets(func),
          ),
        ]),
      )
    _ => return None
  }
  if localized_operands.prefix.length() == 0 {
    Some(replacement_if)
  } else {
    let body = localized_operands.prefix.copy()
    body.push(replacement_if)
    Some(@ir.hot_build_block(func, block_type, body))
  }
}

///|
priv struct OiCallRefChildLayoutFact {
  source_target_id : Int
  effective_target_id : Int
  args : Array[Int]
}

///|
priv struct OiCallRefInvocationFact {
  child_layout_fact : OiCallRefChildLayoutFact
  target_classification_fact : OiCallRefTargetClassificationFact
}

///|
priv struct OiCallRefDirectizationFact {
  invocation_fact : OiCallRefInvocationFact
  plan_fact : OiCallRefDirectizePlanFact
}

///|
priv enum OiCallRefRewriteKind {
  CallRefNullTrapRewrite
  CallRefDirectizationRewrite
}

///|
priv struct OiCallRefRewriteFact {
  kind : OiCallRefRewriteKind
  null_trap_plan : OiCallRefNullTrapPlanFact?
  directization_fact : OiCallRefDirectizationFact?
}

///|
fn OiCallRefChildLayoutFact::from_call_ref(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  node : @ir.HotNode,
) -> OiCallRefChildLayoutFact? {
  // Binaryen v130 `visitCallRef` treats the final child as the callee reference
  // and all earlier children as call operands before applying target-slot
  // `skipNonNullCast`. Keep that child-slot layout and effective-target
  // projection separate from later target classification so null-trap and
  // directization plans share the same source-shaped call_ref record.
  match node.op {
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef => ()
    _ => return None
  }
  if node.child_count < 1 {
    return None
  }
  let callee_ref_id = @ir.hot_child_get(func, node_id, node.child_count - 1)
  if !OiLiveNodeFact::proves_node_live(func, dead, callee_ref_id) {
    return None
  }
  let effective_callee_ref_id = match
    OiCallRefTargetSkipNonNullFact::from_call_ref_target(func, dead, node_id) {
    Some(fact) => fact.effective_target_id()
    None => callee_ref_id
  }
  if effective_callee_ref_id < 0 {
    return None
  }
  let args : Array[Int] = []
  for slot = 0; slot < node.child_count - 1; slot = slot + 1 {
    args.push(@ir.hot_child_get(func, node_id, slot))
  }
  Some({
    source_target_id: callee_ref_id,
    effective_target_id: effective_callee_ref_id,
    args,
  })
}

///|
fn OiCallRefInvocationFact::from_child_layout(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  child_layout_fact : OiCallRefChildLayoutFact,
) -> OiCallRefInvocationFact {
  // Binaryen v130 classifies direct/table/fallthrough/select targets only after
  // the target-slot null-trap opportunity has been considered. Keep the ordered
  // target classification as a fact layered on top of the shared call_ref child
  // layout so null-trap plans can stop before this broader target proof.
  let target_classification_fact = OiCallRefTargetClassificationFact::from_target(
    func,
    dead,
    child_layout_fact.effective_target_id,
  )
  { child_layout_fact, target_classification_fact }
}

///|
fn OiCallRefInvocationFact::target_fact(
  self : OiCallRefInvocationFact,
) -> OiCallRefTargetFact {
  self.target_classification_fact.target_fact()
}

///|
fn OiCallRefDirectizationFact::from_invocation(
  func : @ir.HotFunc,
  invocation_fact : OiCallRefInvocationFact,
) -> OiCallRefDirectizationFact? {
  let plan_fact = match
    OiCallRefDirectizePlanFact::from_target(
      func,
      invocation_fact.target_fact(),
      invocation_fact.child_layout_fact.args,
    ) {
    Some(fact) => fact
    None => return None
  }
  Some({ invocation_fact, plan_fact })
}

///|
fn OiCallRefDirectizationFact::apply(
  self : OiCallRefDirectizationFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if self.invocation_fact.child_layout_fact.source_target_id < 0 ||
    self.invocation_fact.child_layout_fact.effective_target_id < 0 {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let temp = match
    self.plan_fact.build_replacement(
      func,
      node,
      self.invocation_fact.child_layout_fact.effective_target_id,
      self.invocation_fact.child_layout_fact.args,
    ) {
    Some(replacement) => replacement
    None => return false
  }
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  match replacement.op {
    @ir.HotOp::If
    | @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable =>
      @ir.hot_label_owner_set(
        func,
        @ir.hot_control_node_label(func, node_id),
        node_id,
      )
    _ => ()
  }
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn OiCallRefRewriteFact::from_call_ref(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiCallRefRewriteFact? {
  // Binaryen v130 `visitCallRef` runs target `skipNonNullCast`, target
  // `trapOnNull`, direct `ref.func`, immediate `table.get`, fallthrough
  // `ref.func`, and `CallUtils::convertToDirectCalls` in one visitor. Keep that
  // order as a fact-owned rewrite record so callers request a call_ref rewrite
  // without rebuilding the visitor's proof cascade themselves.
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef => ()
    _ => return None
  }
  let child_layout_fact = match
    OiCallRefChildLayoutFact::from_call_ref(func, dead, node_id, node) {
    Some(fact) => fact
    None => return None
  }
  match
    OiCallRefNullTrapPlanFact::from_child_layout(func, dead, child_layout_fact) {
    Some(fact) =>
      return Some({
        kind: CallRefNullTrapRewrite,
        null_trap_plan: Some(fact),
        directization_fact: None,
      })
    None => ()
  }
  let invocation_fact = OiCallRefInvocationFact::from_child_layout(
    func, dead, child_layout_fact,
  )
  match OiCallRefDirectizationFact::from_invocation(func, invocation_fact) {
    Some(fact) =>
      Some({
        kind: CallRefDirectizationRewrite,
        null_trap_plan: None,
        directization_fact: Some(fact),
      })
    None => None
  }
}

///|
fn OiCallRefRewriteFact::apply(
  self : OiCallRefRewriteFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    CallRefNullTrapRewrite =>
      match self.null_trap_plan {
        Some(fact) => fact.apply(ctx, func, node_id)
        None => false
      }
    CallRefDirectizationRewrite =>
      match self.directization_fact {
        Some(fact) => fact.apply(ctx, func, node_id)
        None => false
      }
  }
}

///|
fn optimize_instructions_try_directize_ref_func_call_ref(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiCallRefRewriteFact::from_call_ref(func, dead, node_id) {
    Some(fact) => fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_sink_same_global_set_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_type_results(func, node.ty).length() != 0 {
    return false
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, then_region) != 1 ||
    @ir.hot_region_root_count(func, else_region) != 1 {
    return false
  }
  let then_set_id = @ir.hot_region_get(func, then_region, 0)
  let else_set_id = @ir.hot_region_get(func, else_region, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, then_set_id) ||
    !OiLiveNodeFact::proves_node_live(func, dead, else_set_id) {
    return false
  }
  let then_set = @ir.hot_node_get(func, then_set_id)
  let else_set = @ir.hot_node_get(func, else_set_id)
  let global_id = match (then_set.op, else_set.op) {
    (@ir.HotOp::GlobalSet, @ir.HotOp::GlobalSet) if then_set.imm0 ==
      else_set.imm0 => then_set.imm0
    _ => return false
  }
  if then_set.child_count != 1 || else_set.child_count != 1 {
    return false
  }
  let then_value = @ir.hot_child_get(func, then_set_id, 0)
  let else_value = @ir.hot_child_get(func, else_set_id, 0)
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, then_value) ||
    !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, else_value) {
    return false
  }
  let then_results = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, then_value).ty,
  )
  let else_results = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, else_value).ty,
  )
  if then_results.length() != 1 ||
    else_results.length() != 1 ||
    then_results[0] != else_results[0] {
    return false
  }
  let condition = @ir.hot_child_get(func, node_id, 0)
  let value_if = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(then_results[0]),
    condition,
    [then_value],
    else_body=Some([else_value]),
  )
  let replacement_set = @ir.hot_build_global_set(func, global_id, value_if)
  @ir.hot_control_demote_if_to_block(func, node_id, [replacement_set])
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_fold_constant_if_condition(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_id = @ir.hot_child_get(func, node_id, 0)
  let take_then = match optimize_instructions_i32_const(func, dead, cond_id) {
    Some(@lib.I32(0)) => false
    Some(@lib.I32(_)) => true
    None => return false
  }
  let chosen_region = if take_then {
    @ir.hot_region_then_ref(func, node_id)
  } else {
    match @ir.hot_region_else_ref(func, node_id) {
      Some(region) => region
      None => {
        @ir.hot_control_demote_if_to_block(func, node_id, [])
        pass_mark_mutated(ctx, func)
        return true
      }
    }
  }
  if !precompute_constant_if_chosen_region_can_inline(func, chosen_region) {
    return false
  }
  let root_count = @ir.hot_region_root_count(func, chosen_region)
  let body : Array[Int] = []
  for i = 0; i < root_count; i = i + 1 {
    body.push(@ir.hot_region_get(func, chosen_region, i))
  }
  @ir.hot_control_demote_if_to_block(func, node_id, body)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_i32_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I32? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::I32Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_i64_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I64? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::I64Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_f32_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.F32? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::F32Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_f64_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.F64? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  match func.consts[node.imm0] {
    @ir.HotConstPayload::F64Const(v) => Some(v)
    _ => None
  }
}

///|
fn optimize_instructions_shift_mask_bits(instr : @lib.Instruction) -> Int? {
  match instr {
    @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr => Some(31)
    @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr => Some(63)
    _ => None
  }
}

///|
fn optimize_instructions_shift_rhs_i32_amount(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  rhs_id : Int,
  mask_bits : Int,
) -> Int? {
  match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => return Some(raw & mask_bits)
    None => ()
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
    return None
  }
  let rhs = @ir.hot_node_get(func, rhs_id)
  match rhs.op {
    @ir.HotOp::Binary =>
      match @ir.hot_node_exact_instr(func, rhs_id) {
        Some(@lib.Instruction::I32And) =>
          match
            optimize_instructions_i32_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I32(raw)) if (raw & mask_bits) == mask_bits =>
              match
                optimize_instructions_i32_const(
                  func,
                  dead,
                  func.children[rhs.child_base],
                ) {
                Some(@lib.I32(amount)) => Some(amount & mask_bits)
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn optimize_instructions_shift_rhs_i64_amount(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  rhs_id : Int,
  mask_bits : Int,
) -> Int? {
  match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) => return Some((raw & mask_bits.to_int64()).to_int())
    None => ()
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
    return None
  }
  let rhs = @ir.hot_node_get(func, rhs_id)
  match rhs.op {
    @ir.HotOp::Binary =>
      match @ir.hot_node_exact_instr(func, rhs_id) {
        Some(@lib.Instruction::I64And) =>
          match
            optimize_instructions_i64_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I64(raw)) if (raw & mask_bits.to_int64()) ==
              mask_bits.to_int64() =>
              match
                optimize_instructions_i64_const(
                  func,
                  dead,
                  func.children[rhs.child_base],
                ) {
                Some(@lib.I64(amount)) =>
                  Some((amount & mask_bits.to_int64()).to_int())
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
priv struct OiNonNegativeIntegerFact {
  width_bits : Int
  proven : Bool
}

///|
fn OiNonNegativeIntegerFact::from_i32_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiNonNegativeIntegerFact {
  let proven = match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(raw)) => raw >= 0
    None => false
  }
  { width_bits: 32, proven }
}

///|
fn OiNonNegativeIntegerFact::from_i64_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiNonNegativeIntegerFact {
  let proven = match optimize_instructions_i64_const(func, dead, node_id) {
    Some(@lib.I64(raw)) => raw >= 0L
    None => false
  }
  { width_bits: 64, proven }
}

///|
fn OiNonNegativeIntegerFact::from_unsigned_max(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  width_bits : Int,
) -> OiNonNegativeIntegerFact {
  // Binaryen v130 uses `Bits::getMaxBits(left, this) <= signBit - 1` before
  // rewriting signed compare/div/rem/shr operations to unsigned spellings. The
  // Starshine equivalent is the shared unsigned-max fact: if the fact proves the
  // value cannot reach the sign bit, signed and unsigned operations observe the
  // same nonnegative domain. This owns both direct nonnegative constants and
  // LocalScanner-shaped local/mask/load/shift summaries.
  let proven = match width_bits {
    32 =>
      match
        OiUnsignedMaxValueFact::from_i32_value(func, dead, scratch, node_id).i32_max {
        Some(value) => value <= 2147483647
        None => false
      }
    64 =>
      match
        OiUnsignedMaxValueFact::from_i64_value(func, dead, scratch, node_id).i64_max {
        Some(value) => value <= 9223372036854775807L
        None => false
      }
    _ => false
  }
  { width_bits, proven }
}

///|
fn OiNonNegativeIntegerFact::proves_non_negative(
  self : OiNonNegativeIntegerFact,
  width_bits : Int,
) -> Bool {
  self.width_bits == width_bits && self.proven
}

///|
priv struct OiSignedToUnsignedOpcodeFact {
  width_bits : Int
  unsigned_instr : @lib.Instruction?
}

///|
fn OiSignedToUnsignedOpcodeFact::from_instr(
  instr : @lib.Instruction,
) -> OiSignedToUnsignedOpcodeFact {
  // Mirrors Binaryen v130 `makeUnsignedBinaryOp`: only signed integer
  // comparisons, div/rem, and arithmetic right shift have an unsigned spelling
  // that can replace the original when operand facts prove the nonnegative
  // domain. Keep this table as a fact instead of a naked opcode whitelist.
  match instr {
    @lib.Instruction::I32LtS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_lt_u()) }
    @lib.Instruction::I32GtS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_gt_u()) }
    @lib.Instruction::I32LeS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_le_u()) }
    @lib.Instruction::I32GeS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_ge_u()) }
    @lib.Instruction::I32DivS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_div_u()) }
    @lib.Instruction::I32RemS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_rem_u()) }
    @lib.Instruction::I32ShrS =>
      { width_bits: 32, unsigned_instr: Some(@lib.Instruction::i32_shr_u()) }
    @lib.Instruction::I64LtS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_lt_u()) }
    @lib.Instruction::I64GtS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_gt_u()) }
    @lib.Instruction::I64LeS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_le_u()) }
    @lib.Instruction::I64GeS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_ge_u()) }
    @lib.Instruction::I64DivS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_div_u()) }
    @lib.Instruction::I64RemS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_rem_u()) }
    @lib.Instruction::I64ShrS =>
      { width_bits: 64, unsigned_instr: Some(@lib.Instruction::i64_shr_u()) }
    _ => { width_bits: 0, unsigned_instr: None }
  }
}

///|
fn OiSignedToUnsignedOpcodeFact::replacement(
  self : OiSignedToUnsignedOpcodeFact,
) -> @lib.Instruction? {
  self.unsigned_instr
}

///|
priv struct OiSignedConstUnsignedCanonicalizationFact {
  opcode_fact : OiSignedToUnsignedOpcodeFact
  lhs_fact : OiNonNegativeIntegerFact
  rhs_fact : OiNonNegativeIntegerFact
}

///|
fn OiSignedConstUnsignedCanonicalizationFact::from_binary(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> OiSignedConstUnsignedCanonicalizationFact? {
  // Binaryen v130 runs this source step only when the right operand is a
  // nonnegative constant and the left operand has no sign bit according to
  // `Bits::getMaxBits`. Preserve that asymmetry: a nonconstant nonnegative RHS
  // is not enough, and an arbitrary nonnegative constant LHS does not bypass the
  // shared left unsigned-max fact.
  let opcode_fact = OiSignedToUnsignedOpcodeFact::from_instr(instr)
  let width_bits = opcode_fact.width_bits
  match opcode_fact.replacement() {
    Some(_) => ()
    None => return None
  }
  if width_bits != 32 && width_bits != 64 {
    return None
  }
  let rhs_fact = if width_bits == 32 {
    OiNonNegativeIntegerFact::from_i32_const(func, dead, rhs_id)
  } else {
    OiNonNegativeIntegerFact::from_i64_const(func, dead, rhs_id)
  }
  if !rhs_fact.proves_non_negative(width_bits) {
    return None
  }
  let lhs_fact = OiNonNegativeIntegerFact::from_unsigned_max(
    func, dead, scratch, lhs_id, width_bits,
  )
  if !lhs_fact.proves_non_negative(width_bits) {
    return None
  }
  Some({ opcode_fact, lhs_fact, rhs_fact })
}

///|
fn OiSignedConstUnsignedCanonicalizationFact::replacement(
  self : OiSignedConstUnsignedCanonicalizationFact,
) -> @lib.Instruction? {
  ignore(self.lhs_fact)
  ignore(self.rhs_fact)
  self.opcode_fact.replacement()
}

///|
fn optimize_instructions_try_canonicalize_signed_const_unsigned(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let fact = match
    OiSignedConstUnsignedCanonicalizationFact::from_binary(
      func, dead, scratch, instr, lhs_id, rhs_id,
    ) {
    Some(fact) => fact
    None => return false
  }
  let unsigned_instr = match fact.replacement() {
    Some(instr) => instr
    None => return false
  }
  @ir.hot_node_exact_instr_set(func, node_id, unsigned_instr)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_prefer_negative_leb_i32(raw : Int) -> Bool {
  match raw {
    0x40 | 0x2000 | 0x100000 | 0x8000000 => true
    _ => false
  }
}

///|
fn optimize_instructions_prefer_negative_leb_i64(raw : Int64) -> Bool {
  match raw {
    0x40L
    | 0x2000L
    | 0x100000L
    | 0x8000000L
    | 0x400000000L
    | 0x20000000000L
    | 0x1000000000000L
    | 0x80000000000000L
    | 0x4000000000000000L => true
    _ => false
  }
}

///|
fn optimize_instructions_i32_power_of_two_shift(raw : Int) -> Int? {
  if raw <= 0 || (raw & (raw - 1)) != 0 {
    return None
  }
  let mut shift = 0
  let mut value = raw
  while value > 1 {
    value = value >> 1
    shift = shift + 1
  }
  Some(shift)
}

///|
fn optimize_instructions_i64_power_of_two_shift(raw : Int64) -> Int64? {
  if raw <= 0L || (raw & (raw - 1L)) != 0L {
    return None
  }
  let mut shift = 0L
  let mut value = raw
  while value > 1L {
    value = value >> 1
    shift = shift + 1L
  }
  Some(shift)
}

///|
priv struct OiI32LowOnesMaskFact {
  low_ones : Bool
}

///|
fn OiI32LowOnesMaskFact::from_raw(raw : Int) -> OiI32LowOnesMaskFact {
  { low_ones: raw >= 0 && (raw & (raw + 1)) == 0 }
}

///|
fn OiI32LowOnesMaskFact::proves_low_ones(self : OiI32LowOnesMaskFact) -> Bool {
  self.low_ones
}

///|
priv struct OiI64LowOnesMaskFact {
  low_ones : Bool
}

///|
fn OiI64LowOnesMaskFact::from_raw(raw : Int64) -> OiI64LowOnesMaskFact {
  { low_ones: raw >= 0L && (raw & (raw + 1L)) == 0L }
}

///|
fn OiI64LowOnesMaskFact::proves_low_ones(self : OiI64LowOnesMaskFact) -> Bool {
  self.low_ones
}

///|
priv struct OiCommutativeInstructionFact {
  commutative : Bool
}

///|
fn OiCommutativeInstructionFact::from_instr(
  instr : @lib.Instruction,
) -> OiCommutativeInstructionFact {
  // Binaryen's commutative canonicalization is driven by the operator fact,
  // then gated separately by operand facts/effects. Keep the represented OI-G
  // integer equality/arithmetic subset here rather than at each canonicalizer
  // call site.
  let commutative = match instr {
    @lib.Instruction::I32Add
    | @lib.Instruction::I64Add
    | @lib.Instruction::I32Mul
    | @lib.Instruction::I64Mul
    | @lib.Instruction::I32And
    | @lib.Instruction::I64And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I64Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I32Eq
    | @lib.Instruction::I64Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I64Ne => true
    _ => false
  }
  { commutative, }
}

///|
fn OiCommutativeInstructionFact::proves_commutative(
  self : OiCommutativeInstructionFact,
) -> Bool {
  self.commutative
}

///|
fn OiCommutativeInstructionFact::proves_instr_commutative(
  instr : @lib.Instruction,
) -> Bool {
  OiCommutativeInstructionFact::from_instr(instr).proves_commutative()
}

///|
priv struct OiLocalGetLeafFact {
  local_id : Int?
}

///|
fn OiLocalGetLeafFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiLocalGetLeafFact {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return { local_id: None }
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  {
    local_id: match node.op {
      @ir.HotOp::LocalGet => Some(node.imm0)
      _ => None
    },
  }
}

///|
priv struct OiConstlikeLeafFact {
  live : Bool
  const_leaf : Bool
  ref_null_leaf : Bool
  ref_func_leaf : Bool
}

///|
fn OiConstlikeLeafFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiConstlikeLeafFact {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return {
      live: false,
      const_leaf: false,
      ref_null_leaf: false,
      ref_func_leaf: false,
    }
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  let const_leaf = match node.op {
    @ir.HotOp::Const => true
    _ => false
  }
  let ref_null_leaf = match node.op {
    @ir.HotOp::RefNull => true
    _ => false
  }
  let ref_func_leaf = match node.op {
    @ir.HotOp::RefFunc => true
    _ => false
  }
  { live: true, const_leaf, ref_null_leaf, ref_func_leaf }
}

///|
fn OiConstlikeLeafFact::proves_constlike(self : OiConstlikeLeafFact) -> Bool {
  self.live && (self.const_leaf || self.ref_null_leaf || self.ref_func_leaf)
}

///|
priv struct OiSharedCrossSafeLeafFact {
  live : Bool
  local_get_leaf : Bool
  const_leaf : Bool
  ref_null_leaf : Bool
  ref_func_leaf : Bool
}

///|
fn OiSharedCrossSafeLeafFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiSharedCrossSafeLeafFact {
  // Binaryen v130 local reordering and select cleanup only allow multiply used
  // children to cross a local.get when the child is a direct immutable leaf.
  // Keep Starshine's represented leaf set explicit so local-get crossing,
  // relational canonicalization, and identical-select cleanup share facts
  // instead of each owning an opcode whitelist.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return {
      live: false,
      local_get_leaf: false,
      const_leaf: false,
      ref_null_leaf: false,
      ref_func_leaf: false,
    }
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  let local_get_leaf = match node.op {
    @ir.HotOp::LocalGet => true
    _ => false
  }
  let const_leaf = match node.op {
    @ir.HotOp::Const => true
    _ => false
  }
  let ref_null_leaf = match node.op {
    @ir.HotOp::RefNull => true
    _ => false
  }
  let ref_func_leaf = match node.op {
    @ir.HotOp::RefFunc => true
    _ => false
  }
  { live: true, local_get_leaf, const_leaf, ref_null_leaf, ref_func_leaf }
}

///|
fn OiSharedCrossSafeLeafFact::proves_safe(
  self : OiSharedCrossSafeLeafFact,
) -> Bool {
  self.live &&
  (
    self.local_get_leaf ||
    self.const_leaf ||
    self.ref_null_leaf ||
    self.ref_func_leaf
  )
}

///|
priv struct OiLocalGetCrossingFact {
  live : Bool
  repeated_visit : Bool
  loop_input_boundary : Bool
  unsupported_control : Bool
  shared_use_hazard : Bool
  same_local_write : Bool
  children_can_cross : Bool
}

///|
fn OiLocalGetCrossingFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
  local_id : Int,
  under_local_tee_payload : Bool,
  loop_input_nodes : @bitset.BitSet,
  seen_stamps : Array[Int],
  seen_stamp : Int,
) -> OiLocalGetCrossingFact {
  // Binaryen OI's operand canonicalization may move a subtree across a
  // local.get only when the intervening subtree cannot write that local or hide
  // unsupported control/EH. Preserve the previous Starshine subset as a
  // fact-driven traversal: live/revisit boundaries, loop-input blockers,
  // accepted control roots, shared-use leaf safety, same-local writes, and child
  // crossing all become named evidence fields rather than a standalone scanner.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return {
      live: false,
      repeated_visit: false,
      loop_input_boundary: false,
      unsupported_control: false,
      shared_use_hazard: false,
      same_local_write: false,
      children_can_cross: true,
    }
  }
  if node_id < seen_stamps.length() && seen_stamps[node_id] == seen_stamp {
    return {
      live: true,
      repeated_visit: true,
      loop_input_boundary: false,
      unsupported_control: false,
      shared_use_hazard: false,
      same_local_write: false,
      children_can_cross: true,
    }
  }
  if node_id < seen_stamps.length() {
    seen_stamps[node_id] = seen_stamp
  }
  if node_id < loop_input_nodes.length() && loop_input_nodes[node_id] {
    return {
      live: true,
      repeated_visit: false,
      loop_input_boundary: true,
      unsupported_control: false,
      shared_use_hazard: false,
      same_local_write: false,
      children_can_cross: true,
    }
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  let unsupported_control = match node.op {
    @ir.HotOp::If => false
    @ir.HotOp::Block => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      match @ir.hot_label_kind(func, label_id) {
        @ir.HotLabelKind::RegionLabel => false
        _ => true
      }
    }
    @ir.HotOp::Loop
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Catch
    | @ir.HotOp::CatchAll => true
    _ => false
  }
  let shared_use_hazard = @ir.node_use_count(use_def, node_id) > 1 &&
    (
      !OiSharedCrossSafeLeafFact::from_node(func, dead, node_id).proves_safe() ||
      under_local_tee_payload
    )
  let same_local_write = match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.imm0 == local_id => true
    _ => false
  }
  let mut children_can_cross = true
  if !unsupported_control && !shared_use_hazard && !same_local_write {
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      let child_is_local_tee_payload = match node.op {
        @ir.HotOp::LocalTee => slot == 0
        _ => false
      }
      if !OiLocalGetCrossingFact::from_node(
          func,
          dead,
          use_def,
          func.children[node.child_base + slot],
          local_id,
          child_is_local_tee_payload,
          loop_input_nodes,
          seen_stamps,
          seen_stamp,
        ).proves_can_cross() {
        children_can_cross = false
      }
    }
  }
  {
    live: true,
    repeated_visit: false,
    loop_input_boundary: false,
    unsupported_control,
    shared_use_hazard,
    same_local_write,
    children_can_cross,
  }
}

///|
fn OiLocalGetCrossingFact::proves_can_cross(
  self : OiLocalGetCrossingFact,
) -> Bool {
  ignore(self.live)
  self.repeated_visit ||
  (
    !self.loop_input_boundary &&
    !self.unsupported_control &&
    !self.shared_use_hazard &&
    !self.same_local_write &&
    self.children_can_cross
  )
}

///|
fn optimize_instructions_commutative_node_kind_rank(op : @ir.HotOp) -> Int? {
  match op {
    @ir.HotOp::Call | @ir.HotOp::CallIndirect | @ir.HotOp::CallRef => Some(-1)
    @ir.HotOp::LocalGet => Some(0)
    @ir.HotOp::LocalTee => Some(1)
    @ir.HotOp::GlobalGet => Some(2)
    @ir.HotOp::Load => Some(3)
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => Some(4)
    @ir.HotOp::Unary => Some(5)
    @ir.HotOp::Convert => Some(5)
    @ir.HotOp::Binary => Some(6)
    @ir.HotOp::Compare => Some(7)
    _ => None
  }
}

///|
fn optimize_instructions_should_swap_commutative_node_kinds(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) ||
    !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
    return false
  }
  let lhs = if lhs_id < func.nodes.length() {
    func.nodes[lhs_id]
  } else {
    @ir.hot_node_get(func, lhs_id)
  }
  let rhs = if rhs_id < func.nodes.length() {
    func.nodes[rhs_id]
  } else {
    @ir.hot_node_get(func, rhs_id)
  }
  match
    (
      optimize_instructions_commutative_node_kind_rank(lhs.op),
      optimize_instructions_commutative_node_kind_rank(rhs.op),
    ) {
    (Some(lhs_rank), Some(rhs_rank)) => {
      let local_get_tie_break = match (lhs.op, rhs.op) {
        (@ir.HotOp::LocalGet, @ir.HotOp::LocalGet) => lhs.imm0 > rhs.imm0
        _ => false
      }
      lhs_rank > rhs_rank || (lhs_rank == rhs_rank && local_get_tie_break)
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_canonicalize_commutative(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  // The old O4z guard disabled this after address-like operand reordering bugs.
  // Re-enable only when both the local kind-rank order wants a swap and the
  // shared Binaryen-style effect/use-def proof says the operand subtrees can
  // exchange positions without changing observable behavior.
  ignore(scratch)
  if !optimize_instructions_should_swap_commutative_node_kinds(
      func, dead, lhs_id, rhs_id,
    ) {
    return false
  }
  if !OiLeadingOperandSwapFact::from_operands(ctx, func, lhs_id, rhs_id).proves_swappable() {
    return false
  }
  optimize_instructions_rewrite_exact_with_children(ctx, func, node_id, instr, [
    rhs_id, lhs_id,
  ])
  true
}

///|
priv struct OiTriviallyPureOperandFact {
  local_get_leaf : Bool
  global_get_leaf : Bool
  const_leaf : Bool
  ref_null_leaf : Bool
  ref_func_leaf : Bool
}

///|
fn OiTriviallyPureOperandFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiTriviallyPureOperandFact {
  // Binaryen OI frequently asks whether an operand can be erased without
  // preserving effects. Keep the represented direct leaf set as a fact instead
  // of a helper-local opcode whitelist so descriptor, array, select, compare,
  // and memory facts share the same source-backed predicate.
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet =>
      {
        local_get_leaf: true,
        global_get_leaf: false,
        const_leaf: false,
        ref_null_leaf: false,
        ref_func_leaf: false,
      }
    @ir.HotOp::GlobalGet =>
      {
        local_get_leaf: false,
        global_get_leaf: true,
        const_leaf: false,
        ref_null_leaf: false,
        ref_func_leaf: false,
      }
    @ir.HotOp::Const =>
      {
        local_get_leaf: false,
        global_get_leaf: false,
        const_leaf: true,
        ref_null_leaf: false,
        ref_func_leaf: false,
      }
    @ir.HotOp::RefNull =>
      {
        local_get_leaf: false,
        global_get_leaf: false,
        const_leaf: false,
        ref_null_leaf: true,
        ref_func_leaf: false,
      }
    @ir.HotOp::RefFunc =>
      {
        local_get_leaf: false,
        global_get_leaf: false,
        const_leaf: false,
        ref_null_leaf: false,
        ref_func_leaf: true,
      }
    _ =>
      {
        local_get_leaf: false,
        global_get_leaf: false,
        const_leaf: false,
        ref_null_leaf: false,
        ref_func_leaf: false,
      }
  }
}

///|
fn OiTriviallyPureOperandFact::proves_pure(
  self : OiTriviallyPureOperandFact,
) -> Bool {
  self.local_get_leaf ||
  self.global_get_leaf ||
  self.const_leaf ||
  self.ref_null_leaf ||
  self.ref_func_leaf
}

///|
fn OiTriviallyPureOperandFact::proves_node_pure(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  OiTriviallyPureOperandFact::from_node(func, node_id).proves_pure()
}

///|
fn OiTriviallyPureOperandFact::proves_live_node_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  OiLiveNodeFact::proves_node_live(func, dead, node_id) &&
  OiTriviallyPureOperandFact::proves_node_pure(func, node_id)
}

///|
priv struct OiSideEffectFreeExpressionFact {
  live : Bool
  trivial_leaf : OiTriviallyPureOperandFact
  exact_ref_null_leaf : Bool
  exact_v128_const_leaf : Bool
  ref_i31_payload : Bool
  simd_splat_payload : Bool
  branchless_scalar_shell : Bool
  children_effect_free : Bool
}

///|
fn OiSideEffectFreeExpressionFact::empty() -> OiSideEffectFreeExpressionFact {
  {
    live: false,
    trivial_leaf: {
      local_get_leaf: false,
      global_get_leaf: false,
      const_leaf: false,
      ref_null_leaf: false,
      ref_func_leaf: false,
    },
    exact_ref_null_leaf: false,
    exact_v128_const_leaf: false,
    ref_i31_payload: false,
    simd_splat_payload: false,
    branchless_scalar_shell: false,
    children_effect_free: false,
  }
}

///|
fn OiSideEffectFreeExpressionFact::instr_is_v128_const(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) =>
      true
    _ => false
  }
}

///|
fn OiSideEffectFreeExpressionFact::instr_is_simd_splat(
  instr : @lib.Instruction,
) -> Bool {
  instr == @lib.Instruction::i8x16_splat() ||
  instr == @lib.Instruction::i16x8_splat() ||
  instr == @lib.Instruction::i32x4_splat() ||
  instr == @lib.Instruction::i64x2_splat() ||
  instr == @lib.Instruction::f32x4_splat() ||
  instr == @lib.Instruction::f64x2_splat()
}

///|
fn OiSideEffectFreeExpressionFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiSideEffectFreeExpressionFact {
  // Represented subset of Binaryen v130 `EffectAnalyzer` /
  // `ExpressionAnalyzer` purity queries used by OI when it can erase an
  // operand, collapse identical select arms, move a null check, or replace an
  // expression with a constant while preserving effects. The fact preserves the
  // previous Starshine-supported set exactly: direct pure leaves, exact
  // `ref.null`, byte-constant SIMD leaves, `ref.i31` over side-effect-free
  // payloads, direct SIMD splats over side-effect-free payloads, and branchless
  // scalar shells whose children are all side-effect-free.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return OiSideEffectFreeExpressionFact::empty()
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  let trivial_leaf = OiTriviallyPureOperandFact::from_node(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefNull(_)) =>
      return {
        live: true,
        trivial_leaf,
        exact_ref_null_leaf: true,
        exact_v128_const_leaf: false,
        ref_i31_payload: false,
        simd_splat_payload: false,
        branchless_scalar_shell: false,
        children_effect_free: true,
      }
    Some(instr) if OiSideEffectFreeExpressionFact::instr_is_v128_const(instr) =>
      return {
        live: true,
        trivial_leaf,
        exact_ref_null_leaf: false,
        exact_v128_const_leaf: true,
        ref_i31_payload: false,
        simd_splat_payload: false,
        branchless_scalar_shell: false,
        children_effect_free: true,
      }
    Some(@lib.Instruction::RefI31) if node.child_count == 1 => {
      let child_fact = OiSideEffectFreeExpressionFact::from_node(
        func,
        dead,
        func.children[node.child_base],
      )
      return {
        live: true,
        trivial_leaf,
        exact_ref_null_leaf: false,
        exact_v128_const_leaf: false,
        ref_i31_payload: true,
        simd_splat_payload: false,
        branchless_scalar_shell: false,
        children_effect_free: child_fact.proves_free(),
      }
    }
    Some(instr) if node.child_count == 1 &&
      OiSideEffectFreeExpressionFact::instr_is_simd_splat(instr) => {
      let child_fact = OiSideEffectFreeExpressionFact::from_node(
        func,
        dead,
        func.children[node.child_base],
      )
      return {
        live: true,
        trivial_leaf,
        exact_ref_null_leaf: false,
        exact_v128_const_leaf: false,
        ref_i31_payload: false,
        simd_splat_payload: true,
        branchless_scalar_shell: false,
        children_effect_free: child_fact.proves_free(),
      }
    }
    _ => ()
  }
  if trivial_leaf.proves_pure() {
    return {
      live: true,
      trivial_leaf,
      exact_ref_null_leaf: false,
      exact_v128_const_leaf: false,
      ref_i31_payload: false,
      simd_splat_payload: false,
      branchless_scalar_shell: false,
      children_effect_free: true,
    }
  }
  match node.op {
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => {
      let mut children_effect_free = true
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        let child_fact = OiSideEffectFreeExpressionFact::from_node(
          func,
          dead,
          func.children[node.child_base + slot],
        )
        if !child_fact.proves_free() {
          children_effect_free = false
        }
      }
      {
        live: true,
        trivial_leaf,
        exact_ref_null_leaf: false,
        exact_v128_const_leaf: false,
        ref_i31_payload: false,
        simd_splat_payload: false,
        branchless_scalar_shell: true,
        children_effect_free,
      }
    }
    _ =>
      {
        live: true,
        trivial_leaf,
        exact_ref_null_leaf: false,
        exact_v128_const_leaf: false,
        ref_i31_payload: false,
        simd_splat_payload: false,
        branchless_scalar_shell: false,
        children_effect_free: false,
      }
  }
}

///|
fn OiSideEffectFreeExpressionFact::proves_free(
  self : OiSideEffectFreeExpressionFact,
) -> Bool {
  self.live &&
  (
    self.trivial_leaf.proves_pure() ||
    self.exact_ref_null_leaf ||
    self.exact_v128_const_leaf ||
    (
      (
        self.ref_i31_payload ||
        self.simd_splat_payload ||
        self.branchless_scalar_shell
      ) &&
      self.children_effect_free
    )
  )
}

///|
fn OiSideEffectFreeExpressionFact::proves_node_free(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  OiSideEffectFreeExpressionFact::from_node(func, dead, node_id).proves_free()
}

///|
fn optimize_instructions_negate_boolean_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Eqz) if @ir.hot_child_count(func, node_id) == 1 =>
      Some(@ir.hot_child_get(func, node_id, 0))
    _ =>
      match optimize_instructions_i32_const(func, dead, node_id) {
        Some(@lib.I32(raw)) if raw == 0 =>
          Some(@ir.hot_build_const_i32(func, @lib.I32(1)))
        Some(@lib.I32(raw)) if raw == 1 =>
          Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
        _ => None
      }
  }
}

///|
fn optimize_instructions_negate_boolean_expr_recursive(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => {
      let then_region = @ir.hot_region_then_ref(func, node_id)
      let else_region = match @ir.hot_region_else_ref(func, node_id) {
        Some(region) => region
        None => return None
      }
      if @ir.hot_region_root_count(func, then_region) != 1 ||
        @ir.hot_region_root_count(func, else_region) != 1 {
        return None
      }
      let neg_then = match
        optimize_instructions_negate_boolean_expr_recursive(
          func,
          dead,
          @ir.hot_region_get(func, then_region, 0),
        ) {
        Some(node) => node
        None => return None
      }
      let neg_else = match
        optimize_instructions_negate_boolean_expr_recursive(
          func,
          dead,
          @ir.hot_region_get(func, else_region, 0),
        ) {
        Some(node) => node
        None => return None
      }
      @ir.hot_region_replace_body(func, then_region, [neg_then])
      @ir.hot_region_replace_body(func, else_region, [neg_else])
      return Some(node_id)
    }
    _ => ()
  }
  optimize_instructions_negate_boolean_expr(func, dead, node_id)
}

///|
priv struct OiBooleanConstantTreeFact {
  live : Bool
  exact_i32_false : Bool
  exact_i32_true : Bool
  if_shell : Bool
  has_else : Bool
  single_result_arms : Bool
  then_arm_boolean : Bool
  else_arm_boolean : Bool
}

///|
fn OiBooleanConstantTreeFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiBooleanConstantTreeFact {
  // Binaryen's OI `optimizeBoolean` recursively treats i32-valued `if` arms as
  // boolean contexts, and Starshine's represented nested-boolean cleanup only
  // needs exact `0` / `1` leaves plus single-result `if` trees. Keep that shape
  // as an explicit fact instead of a helper-local recursive scanner.
  let exact_i32_false = match
    optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(0)) => true
    _ => false
  }
  let exact_i32_true = match
    optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(1)) => true
    _ => false
  }
  if exact_i32_false || exact_i32_true {
    return {
      live: true,
      exact_i32_false,
      exact_i32_true,
      if_shell: false,
      has_else: false,
      single_result_arms: true,
      then_arm_boolean: true,
      else_arm_boolean: true,
    }
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return {
      live: false,
      exact_i32_false: false,
      exact_i32_true: false,
      if_shell: false,
      has_else: false,
      single_result_arms: false,
      then_arm_boolean: false,
      else_arm_boolean: false,
    }
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ =>
      return {
        live: true,
        exact_i32_false: false,
        exact_i32_true: false,
        if_shell: false,
        has_else: false,
        single_result_arms: false,
        then_arm_boolean: false,
        else_arm_boolean: false,
      }
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None =>
      return {
        live: true,
        exact_i32_false: false,
        exact_i32_true: false,
        if_shell: true,
        has_else: false,
        single_result_arms: false,
        then_arm_boolean: false,
        else_arm_boolean: false,
      }
  }
  let single_result_arms = @ir.hot_region_root_count(func, then_region) == 1 &&
    @ir.hot_region_root_count(func, else_region) == 1
  if !single_result_arms {
    return {
      live: true,
      exact_i32_false: false,
      exact_i32_true: false,
      if_shell: true,
      has_else: true,
      single_result_arms,
      then_arm_boolean: false,
      else_arm_boolean: false,
    }
  }
  let then_fact = OiBooleanConstantTreeFact::from_node(
    func,
    dead,
    @ir.hot_region_get(func, then_region, 0),
  )
  let else_fact = OiBooleanConstantTreeFact::from_node(
    func,
    dead,
    @ir.hot_region_get(func, else_region, 0),
  )
  {
    live: true,
    exact_i32_false: false,
    exact_i32_true: false,
    if_shell: true,
    has_else: true,
    single_result_arms,
    then_arm_boolean: then_fact.proves_boolean_tree(),
    else_arm_boolean: else_fact.proves_boolean_tree(),
  }
}

///|
fn OiBooleanConstantTreeFact::proves_boolean_tree(
  self : OiBooleanConstantTreeFact,
) -> Bool {
  self.live &&
  (
    self.exact_i32_false ||
    self.exact_i32_true ||
    (
      self.if_shell &&
      self.has_else &&
      self.single_result_arms &&
      self.then_arm_boolean &&
      self.else_arm_boolean
    )
  )
}

///|
fn OiBooleanConstantTreeFact::proves_node_boolean_tree(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  OiBooleanConstantTreeFact::from_node(func, dead, node_id).proves_boolean_tree()
}

///|
priv struct OiBooleanTreeUnsharedFact {
  live : Bool
  direct_eqz_leaf : Bool
  exact_i32_false : Bool
  exact_i32_true : Bool
  use_count_allows_if : Bool
  if_shell : Bool
  has_else : Bool
  single_result_arms : Bool
  then_arm_allowed : Bool
  else_arm_allowed : Bool
}

///|
fn OiBooleanTreeUnsharedFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
) -> OiBooleanTreeUnsharedFact {
  // Source-backed subset for Binaryen's nested boolean-condition rewrites:
  // direct `eqz`, exact boolean constants, and recursively unshared one-result
  // `if` arms. This records the sharing gate as data instead of letting callers
  // embed the old tree scanner.
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return {
      live: false,
      direct_eqz_leaf: false,
      exact_i32_false: false,
      exact_i32_true: false,
      use_count_allows_if: false,
      if_shell: false,
      has_else: false,
      single_result_arms: false,
      then_arm_allowed: false,
      else_arm_allowed: false,
    }
  }
  let direct_eqz_leaf = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Eqz) if @ir.hot_child_count(func, node_id) == 1 =>
      true
    _ => false
  }
  let exact_i32_false = match
    optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(0)) => true
    _ => false
  }
  let exact_i32_true = match
    optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(1)) => true
    _ => false
  }
  if direct_eqz_leaf || exact_i32_false || exact_i32_true {
    return {
      live: true,
      direct_eqz_leaf,
      exact_i32_false,
      exact_i32_true,
      use_count_allows_if: true,
      if_shell: false,
      has_else: false,
      single_result_arms: true,
      then_arm_allowed: true,
      else_arm_allowed: true,
    }
  }
  let use_count_allows_if = @ir.node_use_count(use_def, node_id) <= 1
  if !use_count_allows_if {
    return {
      live: true,
      direct_eqz_leaf: false,
      exact_i32_false: false,
      exact_i32_true: false,
      use_count_allows_if,
      if_shell: false,
      has_else: false,
      single_result_arms: false,
      then_arm_allowed: false,
      else_arm_allowed: false,
    }
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ =>
      return {
        live: true,
        direct_eqz_leaf: false,
        exact_i32_false: false,
        exact_i32_true: false,
        use_count_allows_if,
        if_shell: false,
        has_else: false,
        single_result_arms: false,
        then_arm_allowed: false,
        else_arm_allowed: false,
      }
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None =>
      return {
        live: true,
        direct_eqz_leaf: false,
        exact_i32_false: false,
        exact_i32_true: false,
        use_count_allows_if,
        if_shell: true,
        has_else: false,
        single_result_arms: false,
        then_arm_allowed: false,
        else_arm_allowed: false,
      }
  }
  let single_result_arms = @ir.hot_region_root_count(func, then_region) == 1 &&
    @ir.hot_region_root_count(func, else_region) == 1
  if !single_result_arms {
    return {
      live: true,
      direct_eqz_leaf: false,
      exact_i32_false: false,
      exact_i32_true: false,
      use_count_allows_if,
      if_shell: true,
      has_else: true,
      single_result_arms,
      then_arm_allowed: false,
      else_arm_allowed: false,
    }
  }
  let then_fact = OiBooleanTreeUnsharedFact::from_node(
    func,
    dead,
    use_def,
    @ir.hot_region_get(func, then_region, 0),
  )
  let else_fact = OiBooleanTreeUnsharedFact::from_node(
    func,
    dead,
    use_def,
    @ir.hot_region_get(func, else_region, 0),
  )
  {
    live: true,
    direct_eqz_leaf: false,
    exact_i32_false: false,
    exact_i32_true: false,
    use_count_allows_if,
    if_shell: true,
    has_else: true,
    single_result_arms,
    then_arm_allowed: then_fact.proves_allowed_tree(),
    else_arm_allowed: else_fact.proves_allowed_tree(),
  }
}

///|
fn OiBooleanTreeUnsharedFact::proves_allowed_tree(
  self : OiBooleanTreeUnsharedFact,
) -> Bool {
  self.live &&
  (
    self.direct_eqz_leaf ||
    self.exact_i32_false ||
    self.exact_i32_true ||
    (
      self.use_count_allows_if &&
      self.if_shell &&
      self.has_else &&
      self.single_result_arms &&
      self.then_arm_allowed &&
      self.else_arm_allowed
    )
  )
}

///|
fn optimize_instructions_boolean_tree_if_nodes_are_unshared(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
) -> Bool {
  OiBooleanTreeUnsharedFact::from_node(func, dead, use_def, node_id).proves_allowed_tree()
}

///|
priv struct OiBranchShapeFact {
  lhs_live : Bool
  rhs_live : Bool
  both_br : Bool
  same_label : Bool
  same_arity : Bool
  same_operands : Bool
}

///|
fn OiBranchShapeFact::from_pair(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> OiBranchShapeFact {
  // The represented duplicate-branch collapse mirrors Binaryen's ability to
  // fold identical branch arms after condition cleanup, but HOT only rewrites
  // direct `br` roots with byte-identical target label and value operands. Make
  // those branch-control facts explicit so future `br_if`/fallthrough work can
  // extend the fact instead of adding ad hoc branch scanners.
  let lhs_live = OiLiveNodeFact::proves_node_live(func, dead, lhs_id)
  let rhs_live = OiLiveNodeFact::proves_node_live(func, dead, rhs_id)
  if !lhs_live || !rhs_live {
    return {
      lhs_live,
      rhs_live,
      both_br: false,
      same_label: false,
      same_arity: false,
      same_operands: false,
    }
  }
  let lhs = @ir.hot_node_get(func, lhs_id)
  let rhs = @ir.hot_node_get(func, rhs_id)
  let both_br = match (lhs.op, rhs.op) {
    (@ir.HotOp::Br, @ir.HotOp::Br) => true
    _ => false
  }
  let same_label = both_br && lhs.imm0 == rhs.imm0
  let same_arity = both_br && lhs.child_count == rhs.child_count
  let mut same_operands = both_br && same_arity
  if same_operands {
    for slot = 0; slot < lhs.child_count; slot = slot + 1 {
      if @ir.hot_child_get(func, lhs_id, slot) !=
        @ir.hot_child_get(func, rhs_id, slot) {
        same_operands = false
      }
    }
  }
  { lhs_live, rhs_live, both_br, same_label, same_arity, same_operands }
}

///|
fn OiBranchShapeFact::proves_same_direct_branch(
  self : OiBranchShapeFact,
) -> Bool {
  self.lhs_live &&
  self.rhs_live &&
  self.both_br &&
  self.same_label &&
  self.same_arity &&
  self.same_operands
}

///|
fn optimize_instructions_same_branch_shape(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  OiBranchShapeFact::from_pair(func, dead, lhs_id, rhs_id).proves_same_direct_branch()
}

///|
fn optimize_instructions_try_collapse_duplicate_then_branch(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let then_root_count = @ir.hot_region_root_count(func, then_region)
  if then_root_count != 1 && then_root_count != 2 {
    return false
  }
  let inner_if_id = @ir.hot_region_get(func, then_region, 0)
  if then_root_count == 2 {
    let tail_id = @ir.hot_region_get(func, then_region, 1)
    match @ir.hot_node_get(func, tail_id).op {
      @ir.HotOp::Unreachable => ()
      _ => return false
    }
  }
  match @ir.hot_node_get(func, inner_if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let inner_else = match @ir.hot_region_else_ref(func, inner_if_id) {
    Some(region) => region
    None => return false
  }
  let inner_then = @ir.hot_region_then_ref(func, inner_if_id)
  if @ir.hot_region_root_count(func, inner_then) != 1 ||
    @ir.hot_region_root_count(func, inner_else) != 1 {
    return false
  }
  let inner_cond_id = @ir.hot_child_get(func, inner_if_id, 0)
  if !OiSideEffectFreeExpressionFact::proves_node_free(
      func, dead, inner_cond_id,
    ) {
    return false
  }
  let then_root = @ir.hot_region_get(func, inner_then, 0)
  let else_root = @ir.hot_region_get(func, inner_else, 0)
  if !optimize_instructions_same_branch_shape(func, dead, then_root, else_root) {
    return false
  }
  let branch = @ir.hot_node_get(func, then_root)
  let replacement = @ir.hot_build_br(
    func,
    branch.imm0,
    values=@ir.hot_child_span(func, then_root),
  )
  @ir.hot_region_replace_body(func, then_region, [replacement])
  pass_mark_mutated(ctx, func)
  true
}

///|
priv struct OiZeroSentinelFact {
  exact_i32_zero : Bool
  drop_shell : Bool
  single_drop_child : Bool
  child_zero_sentinel : Bool
}

///|
fn OiZeroSentinelFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiZeroSentinelFact {
  // Starshine's dead-suffix cleanup uses explicit zero sentinels to avoid
  // deleting value carriers that still satisfy a surrounding drop or result
  // shape. Record the direct `i32.const 0` / nested `drop` proof as a fact so
  // the cleanup does not own a recursive opcode scanner.
  let node = @ir.hot_node_get(func, node_id)
  let exact_i32_zero = match node.op {
    @ir.HotOp::Const =>
      @ir.hot_const_get(func, node.imm0) ==
      @ir.HotConstPayload::i32_const(@lib.I32(0))
    _ => false
  }
  let drop_shell = match node.op {
    @ir.HotOp::Drop => true
    _ => false
  }
  let single_drop_child = drop_shell && @ir.hot_child_count(func, node_id) == 1
  let child_zero_sentinel = if single_drop_child {
    OiZeroSentinelFact::from_node(func, @ir.hot_child_get(func, node_id, 0)).proves_zero_sentinel()
  } else {
    false
  }
  { exact_i32_zero, drop_shell, single_drop_child, child_zero_sentinel }
}

///|
fn OiZeroSentinelFact::proves_zero_sentinel(self : OiZeroSentinelFact) -> Bool {
  self.exact_i32_zero ||
  (self.drop_shell && self.single_drop_child && self.child_zero_sentinel)
}

///|
fn OiZeroSentinelFact::proves_drop_zero_sentinel(
  self : OiZeroSentinelFact,
) -> Bool {
  self.drop_shell && self.single_drop_child && self.child_zero_sentinel
}

///|
fn OiZeroSentinelFact::proves_node_zero_sentinel(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  OiZeroSentinelFact::from_node(func, node_id).proves_zero_sentinel()
}

///|
fn OiZeroSentinelFact::proves_node_drop_zero_sentinel(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  OiZeroSentinelFact::from_node(func, node_id).proves_drop_zero_sentinel()
}

///|
priv struct OiBranchTableTargetFact {
  default_targets_label : Bool
  all_targets_label : Bool
}

///|
fn OiBranchTableTargetFact::from_table(
  func : @ir.HotFunc,
  table_id : Int,
  label_id : Int,
) -> OiBranchTableTargetFact {
  let default_targets_label = @ir.hot_branch_table_default_target(
      func, table_id,
    ) ==
    label_id
  let mut all_targets_label = default_targets_label
  if all_targets_label {
    for target in @ir.hot_branch_table_targets(func, table_id) {
      if target != label_id {
        all_targets_label = false
      }
    }
  }
  { default_targets_label, all_targets_label }
}

///|
fn OiBranchTableTargetFact::proves_all_targets_label(
  self : OiBranchTableTargetFact,
) -> Bool {
  self.default_targets_label && self.all_targets_label
}

///|
priv struct OiControlExitFact {
  live : Bool
  direct_nonbranch_terminal : Bool
  direct_branch_terminal : Bool
  direct_br_to_label : Bool
  branch_table_targets_label : Bool
  if_shell : Bool
  has_else : Bool
  then_never_falls_through : Bool
  else_never_falls_through : Bool
  then_never_falls_through_to_label : Bool
  else_never_falls_through_to_label : Bool
  then_exits_to_label : Bool
  else_exits_to_label : Bool
  then_exits_only_via_branches : Bool
  else_exits_only_via_branches : Bool
  then_branches_to_label : Bool
  else_branches_to_label : Bool
  block_shell : Bool
  block_exits_via_nonbranch_terminal : Bool
  then_exits_via_nonbranch_terminal : Bool
  else_exits_via_nonbranch_terminal : Bool
}

///|
priv struct OiControlExitRegionFact {
  empty : Bool
  tail_never_falls_through : Bool
  tail_never_falls_through_to_label : Bool
  tail_exits_to_label : Bool
  tail_exits_only_via_branches : Bool
  tail_branches_to_label : Bool
  exits_via_nonbranch_terminal : Bool
}

///|
fn OiControlExitFact::empty(live : Bool) -> OiControlExitFact {
  {
    live,
    direct_nonbranch_terminal: false,
    direct_branch_terminal: false,
    direct_br_to_label: false,
    branch_table_targets_label: false,
    if_shell: false,
    has_else: false,
    then_never_falls_through: false,
    else_never_falls_through: false,
    then_never_falls_through_to_label: false,
    else_never_falls_through_to_label: false,
    then_exits_to_label: false,
    else_exits_to_label: false,
    then_exits_only_via_branches: false,
    else_exits_only_via_branches: false,
    then_branches_to_label: false,
    else_branches_to_label: false,
    block_shell: false,
    block_exits_via_nonbranch_terminal: false,
    then_exits_via_nonbranch_terminal: false,
    else_exits_via_nonbranch_terminal: false,
  }
}

///|
fn OiControlExitFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> OiControlExitFact {
  // Binaryen's OI relies on control/fallthrough facts when deleting dead
  // suffixes and preserving branch-carried values. Starshine's represented
  // cleanup keeps a narrower HOT subset: direct nonbranch terminals, direct
  // branch terminals, all-target `br_table`s, and two-arm `if` summaries. Keep
  // those exit proofs as a single fact instead of several recursive helpers.
  let live = OiLiveNodeFact::proves_node_live(func, dead, node_id)
  if !live {
    return OiControlExitFact::empty(false)
  }
  let node = @ir.hot_node_get(func, node_id)
  let direct_nonbranch_terminal = match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    _ => false
  }
  let direct_branch_terminal = match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrTable => true
    _ => false
  }
  let direct_br_to_label = match node.op {
    @ir.HotOp::Br => node.imm0 == label_id
    _ => false
  }
  let branch_table_targets_label = match node.op {
    @ir.HotOp::BrTable =>
      OiBranchTableTargetFact::from_table(func, node.imm0, label_id).proves_all_targets_label()
    _ => false
  }
  match node.op {
    @ir.HotOp::If => {
      let base = OiControlExitFact::empty(true)
      let else_region = match @ir.hot_region_else_ref(func, node_id) {
        Some(region) => region
        None => return { ..base, if_shell: true }
      }
      let then_fact = OiControlExitRegionFact::from_region(
        func,
        dead,
        @ir.hot_region_then_ref(func, node_id),
        label_id,
      )
      let else_fact = OiControlExitRegionFact::from_region(
        func, dead, else_region, label_id,
      )
      return {
        ..base,
        if_shell: true,
        has_else: true,
        then_never_falls_through: then_fact.proves_never_falls_through(),
        else_never_falls_through: else_fact.proves_never_falls_through(),
        then_never_falls_through_to_label: then_fact.proves_never_falls_through_to_label(),
        else_never_falls_through_to_label: else_fact.proves_never_falls_through_to_label(),
        then_exits_to_label: then_fact.proves_exits_to_label(),
        else_exits_to_label: else_fact.proves_exits_to_label(),
        then_exits_only_via_branches: then_fact.proves_exits_only_via_branches(),
        else_exits_only_via_branches: else_fact.proves_exits_only_via_branches(),
        then_branches_to_label: then_fact.proves_branches_to_label(),
        else_branches_to_label: else_fact.proves_branches_to_label(),
        then_exits_via_nonbranch_terminal: then_fact.proves_exits_via_nonbranch_terminal(),
        else_exits_via_nonbranch_terminal: else_fact.proves_exits_via_nonbranch_terminal(),
      }
    }
    @ir.HotOp::Block => {
      let body_fact = OiControlExitRegionFact::from_region(
        func,
        dead,
        @ir.hot_region_body_ref(func, node_id),
        label_id,
      )
      return {
        ..OiControlExitFact::empty(true),
        block_shell: true,
        block_exits_via_nonbranch_terminal: body_fact.proves_exits_via_nonbranch_terminal(),
      }
    }
    _ => ()
  }
  {
    ..OiControlExitFact::empty(true),
    direct_nonbranch_terminal,
    direct_branch_terminal,
    direct_br_to_label,
    branch_table_targets_label,
  }
}

///|
fn OiControlExitFact::proves_direct_terminal(self : OiControlExitFact) -> Bool {
  self.live && (self.direct_nonbranch_terminal || self.direct_branch_terminal)
}

///|
fn OiControlExitFact::proves_never_falls_through(
  self : OiControlExitFact,
) -> Bool {
  self.live &&
  (
    self.direct_nonbranch_terminal ||
    self.direct_branch_terminal ||
    (
      self.if_shell &&
      self.has_else &&
      self.then_never_falls_through &&
      self.else_never_falls_through
    )
  )
}

///|
fn OiControlExitFact::proves_never_falls_through_to_label(
  self : OiControlExitFact,
) -> Bool {
  self.live &&
  (
    self.direct_nonbranch_terminal ||
    self.direct_br_to_label ||
    self.branch_table_targets_label ||
    (
      self.if_shell &&
      self.has_else &&
      self.then_never_falls_through_to_label &&
      self.else_never_falls_through_to_label
    )
  )
}

///|
fn OiControlExitFact::proves_exits_to_label(self : OiControlExitFact) -> Bool {
  self.live &&
  (
    self.direct_nonbranch_terminal ||
    self.direct_br_to_label ||
    self.branch_table_targets_label ||
    (
      self.if_shell &&
      self.has_else &&
      self.then_exits_to_label &&
      self.else_exits_to_label
    )
  )
}

///|
fn OiControlExitFact::proves_exits_only_via_branches(
  self : OiControlExitFact,
) -> Bool {
  self.live &&
  (
    self.direct_branch_terminal ||
    (
      self.if_shell &&
      self.has_else &&
      self.then_exits_only_via_branches &&
      self.else_exits_only_via_branches
    )
  )
}

///|
fn OiControlExitFact::proves_branches_to_label(
  self : OiControlExitFact,
) -> Bool {
  self.live &&
  (
    self.direct_br_to_label ||
    (
      self.if_shell &&
      self.has_else &&
      self.then_branches_to_label &&
      self.else_branches_to_label
    )
  )
}

///|
fn OiControlExitFact::proves_exits_via_nonbranch_terminal(
  self : OiControlExitFact,
) -> Bool {
  self.live &&
  (
    self.direct_nonbranch_terminal ||
    (self.block_shell && self.block_exits_via_nonbranch_terminal) ||
    (
      self.if_shell &&
      self.has_else &&
      self.then_exits_via_nonbranch_terminal &&
      self.else_exits_via_nonbranch_terminal
    )
  )
}

///|
fn OiControlExitRegionFact::from_region(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> OiControlExitRegionFact {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return OiControlExitRegionFact::empty()
  }
  let tail_fact = OiControlExitFact::from_node(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
  for idx = 0; idx < root_count; idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    if !OiLiveNodeFact::proves_node_live(func, dead, root) {
      continue
    }
    let root_fact = OiControlExitFact::from_node(func, dead, root, label_id)
    if root_fact.proves_exits_via_nonbranch_terminal() {
      return {
        empty: false,
        tail_never_falls_through: tail_fact.proves_never_falls_through(),
        tail_never_falls_through_to_label: tail_fact.proves_never_falls_through_to_label(),
        tail_exits_to_label: tail_fact.proves_exits_to_label(),
        tail_exits_only_via_branches: tail_fact.proves_exits_only_via_branches(),
        tail_branches_to_label: tail_fact.proves_branches_to_label(),
        exits_via_nonbranch_terminal: true,
      }
    }
    if root_fact.proves_never_falls_through() {
      return {
        empty: false,
        tail_never_falls_through: tail_fact.proves_never_falls_through(),
        tail_never_falls_through_to_label: tail_fact.proves_never_falls_through_to_label(),
        tail_exits_to_label: tail_fact.proves_exits_to_label(),
        tail_exits_only_via_branches: tail_fact.proves_exits_only_via_branches(),
        tail_branches_to_label: tail_fact.proves_branches_to_label(),
        exits_via_nonbranch_terminal: false,
      }
    }
  }
  {
    empty: false,
    tail_never_falls_through: tail_fact.proves_never_falls_through(),
    tail_never_falls_through_to_label: tail_fact.proves_never_falls_through_to_label(),
    tail_exits_to_label: tail_fact.proves_exits_to_label(),
    tail_exits_only_via_branches: tail_fact.proves_exits_only_via_branches(),
    tail_branches_to_label: tail_fact.proves_branches_to_label(),
    exits_via_nonbranch_terminal: false,
  }
}

///|
fn OiControlExitRegionFact::empty() -> OiControlExitRegionFact {
  {
    empty: true,
    tail_never_falls_through: false,
    tail_never_falls_through_to_label: false,
    tail_exits_to_label: false,
    tail_exits_only_via_branches: false,
    tail_branches_to_label: false,
    exits_via_nonbranch_terminal: false,
  }
}

///|
fn OiControlExitRegionFact::proves_never_falls_through(
  self : OiControlExitRegionFact,
) -> Bool {
  !self.empty && self.tail_never_falls_through
}

///|
fn OiControlExitRegionFact::proves_never_falls_through_to_label(
  self : OiControlExitRegionFact,
) -> Bool {
  !self.empty && self.tail_never_falls_through_to_label
}

///|
fn OiControlExitRegionFact::proves_exits_to_label(
  self : OiControlExitRegionFact,
) -> Bool {
  !self.empty && self.tail_exits_to_label
}

///|
fn OiControlExitRegionFact::proves_exits_only_via_branches(
  self : OiControlExitRegionFact,
) -> Bool {
  !self.empty && self.tail_exits_only_via_branches
}

///|
fn OiControlExitRegionFact::proves_branches_to_label(
  self : OiControlExitRegionFact,
) -> Bool {
  !self.empty && self.tail_branches_to_label
}

///|
fn OiControlExitRegionFact::proves_exits_via_nonbranch_terminal(
  self : OiControlExitRegionFact,
) -> Bool {
  !self.empty && self.exits_via_nonbranch_terminal
}

///|
fn optimize_instructions_holder_flows_to_drop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if region_ref == @ir.HotRegionRef::root() {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  let mut current = region_ref.holder
  for hops = 0; hops < 64; hops = hops + 1 {
    if @ir.node_use_count(use_def, current) != 1 {
      return false
    }
    let sites = @ir.node_use_sites_borrowed(use_def, current)
    let site = sites[0]
    if site.user == -1 {
      return false
    }
    let user = @ir.hot_node_get(func, site.user)
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot =>
        match user.op {
          @ir.HotOp::Drop => return true
          _ => return false
        }
      @ir.HotUseSlotKind::RootUseSlot => current = site.user
    }
  }
  false
}

///|
fn optimize_instructions_try_collapse_dead_region_suffix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count < 2 {
    return false
  }
  for idx = 0; idx < root_count - 1; idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    let root_op = @ir.hot_node_get(func, root).op
    let root_exit_fact = OiControlExitFact::from_node(
      func, dead, root, label_id,
    )
    let branch_only_if_escape = match root_op {
      @ir.HotOp::If => root_exit_fact.proves_exits_only_via_branches()
      _ => false
    }
    let direct_terminal = root_exit_fact.proves_direct_terminal()
    let tail_is_value_branch_to_label = if idx + 2 == root_count {
      let tail_id = @ir.hot_region_get(func, region_ref, idx + 1)
      let tail = @ir.hot_node_get(func, tail_id)
      match tail.op {
        @ir.HotOp::Br =>
          tail.imm0 == label_id && @ir.hot_child_count(func, tail_id) > 0
        _ => false
      }
    } else {
      false
    }
    let never_falls_through = if tail_is_value_branch_to_label {
      root_exit_fact.proves_never_falls_through_to_label()
    } else {
      root_exit_fact.proves_never_falls_through()
    }
    let escapes = if branch_only_if_escape {
      false
    } else {
      match root_op {
        @ir.HotOp::Br
        | @ir.HotOp::BrTable
        | @ir.HotOp::Unreachable
        | @ir.HotOp::Return
        | @ir.HotOp::Throw
        | @ir.HotOp::Rethrow
        | @ir.HotOp::ThrowRef
        | @ir.HotOp::Delegate => true
        _ => root_exit_fact.proves_exits_to_label() || never_falls_through
      }
    }
    if !escapes {
      continue
    }
    if idx + 2 == root_count {
      let tail_id = @ir.hot_region_get(func, region_ref, idx + 1)
      let root_is_if = match root_op {
        @ir.HotOp::If => true
        _ => false
      }
      if root_is_if &&
        OiZeroSentinelFact::proves_node_drop_zero_sentinel(func, tail_id) {
        return false
      }
      let root_is_result_carrier = match root_op {
        @ir.HotOp::If | @ir.HotOp::Block => true
        _ => false
      }
      let keep_result_zero_sentinel = root_is_result_carrier &&
        root_exit_fact.proves_exits_via_nonbranch_terminal()
      if OiZeroSentinelFact::proves_node_zero_sentinel(func, tail_id) &&
        (
          optimize_instructions_holder_flows_to_drop(ctx, func, region_ref) ||
          keep_result_zero_sentinel
        ) {
        return false
      }
    }
    if idx + 2 == root_count {
      let tail_id = @ir.hot_region_get(func, region_ref, idx + 1)
      let tail = @ir.hot_node_get(func, tail_id)
      match tail.op {
        @ir.HotOp::Unreachable => return false
        @ir.HotOp::Br =>
          if @ir.hot_child_count(func, tail_id) > 0 {
            let root_is_if = match root_op {
              @ir.HotOp::If => true
              _ => false
            }
            if root_is_if &&
              !OiControlExitFact::from_node(func, dead, root, tail.imm0).proves_exits_to_label() {
              return false
            }
          }
        _ => ()
      }
    }
    let next : Array[Int] = []
    for keep = 0; keep <= idx; keep = keep + 1 {
      next.push(@ir.hot_region_get(func, region_ref, keep))
    }
    let root_is_if = match root_op {
      @ir.HotOp::If => true
      _ => false
    }
    let needs_unreachable = if direct_terminal {
      false
    } else if root_is_if && branch_only_if_escape {
      false
    } else if region_ref == @ir.HotRegionRef::root() {
      true
    } else {
      let holder = region_ref.holder
      let holder_label = @ir.hot_control_node_label(func, holder)
      match @ir.hot_label_kind(func, holder_label) {
        @ir.HotLabelKind::RegionLabel => false
        _ => true
      }
    }
    if needs_unreachable {
      next.push(@ir.hot_build_unreachable(func))
    }
    @ir.hot_region_replace_body(func, region_ref, next)
    pass_mark_mutated(ctx, func)
    return true
  }
  false
}

///|
fn optimize_instructions_reverse_relational_instr(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_gt_s())
    @lib.Instruction::I32LtU => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_ge_s())
    @lib.Instruction::I32LeU => Some(@lib.Instruction::i32_ge_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_lt_s())
    @lib.Instruction::I32GtU => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_le_s())
    @lib.Instruction::I32GeU => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_gt_s())
    @lib.Instruction::I64LtU => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_ge_s())
    @lib.Instruction::I64LeU => Some(@lib.Instruction::i64_ge_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_lt_s())
    @lib.Instruction::I64GtU => Some(@lib.Instruction::i64_lt_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_le_s())
    @lib.Instruction::I64GeU => Some(@lib.Instruction::i64_le_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_canonicalize_relational_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !OiConstlikeLeafFact::from_node(func, dead, lhs_id).proves_constlike() ||
    OiConstlikeLeafFact::from_node(func, dead, rhs_id).proves_constlike() {
    return false
  }
  match optimize_instructions_reverse_relational_instr(instr) {
    Some(reversed) => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        reversed,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_canonicalize_relational_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  let reversed = match optimize_instructions_reverse_relational_instr(instr) {
    Some(reversed) => reversed
    None => return false
  }
  let lhs_canonicalized = match
    OiLocalGetLeafFact::from_node(func, dead, lhs_id).local_id {
    Some(local_id) => {
      if OiConstlikeLeafFact::from_node(func, dead, rhs_id).proves_constlike() {
        return false
      }
      let should_swap = match
        OiLocalGetLeafFact::from_node(func, dead, rhs_id).local_id {
        Some(rhs_local_id) => local_id > rhs_local_id
        None => true
      }
      if !should_swap {
        return false
      }
      let use_def = pass_require_use_def(ctx, func)
      if @ir.node_use_count(use_def, rhs_id) > 1 {
        return false
      }
      optimize_instructions_mark_loop_input_nodes(func, dead, scratch)
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = OiLocalGetCrossingFact::from_node(
        func,
        dead,
        use_def,
        rhs_id,
        local_id,
        false,
        scratch.loop_input_nodes,
        scratch.cross_seen_stamps,
        seen_stamp,
      ).proves_can_cross()
      if !can_cross {
        return false
      }
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        reversed,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
  if lhs_canonicalized {
    return true
  }
  match OiLocalGetLeafFact::from_node(func, dead, rhs_id).local_id {
    Some(local_id) => {
      if OiConstlikeLeafFact::from_node(func, dead, lhs_id).proves_constlike() ||
        !optimize_instructions_should_swap_commutative_node_kinds(
          func, dead, lhs_id, rhs_id,
        ) {
        return false
      }
      let use_def = pass_require_use_def(ctx, func)
      if @ir.node_use_count(use_def, lhs_id) > 1 {
        return false
      }
      optimize_instructions_mark_loop_input_nodes(func, dead, scratch)
      let seen_stamp = optimize_instructions_alloc_cross_seen_stamp(scratch)
      let can_cross = OiLocalGetCrossingFact::from_node(
        func,
        dead,
        use_def,
        lhs_id,
        local_id,
        false,
        scratch.loop_input_nodes,
        scratch.cross_seen_stamps,
        seen_stamp,
      ).proves_can_cross()
      if !can_cross {
        return false
      }
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        reversed,
        [rhs_id, lhs_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_canonicalize_compare_const(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32GtS, Some(@lib.I32(raw))) if raw == -1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ge_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LeS, Some(@lib.I32(raw))) if raw == -1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_lt_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LtS, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_le_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32GeS, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_gt_s(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LtU, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eq(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32GeU, Some(@lib.I32(raw))) if raw == 1 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(0))],
      )
      true
    }
    (@lib.Instruction::I32LtS, Some(@lib.I32(raw))) if raw == -2147483647 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eq(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(-2147483648))],
      )
      true
    }
    (@lib.Instruction::I32GeS, Some(@lib.I32(raw))) if raw == -2147483647 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(-2147483648))],
      )
      true
    }
    (@lib.Instruction::I32GtS, Some(@lib.I32(raw))) if raw == 2147483646 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eq(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(2147483647))],
      )
      true
    }
    (@lib.Instruction::I32LeS, Some(@lib.I32(raw))) if raw == 2147483646 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(2147483647))],
      )
      true
    }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64GtS, Some(@lib.I64(raw))) if raw == -1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ge_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LeS, Some(@lib.I64(raw))) if raw == -1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_lt_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LtS, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_le_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64GeS, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_gt_s(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LtU, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64GeU, Some(@lib.I64(raw))) if raw == 1L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(0L))],
          )
          true
        }
        (@lib.Instruction::I64LtS, Some(@lib.I64(raw))) if raw ==
          -9223372036854775807L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(-9223372036854775808L)),
            ],
          )
          true
        }
        (@lib.Instruction::I64GeS, Some(@lib.I64(raw))) if raw ==
          -9223372036854775807L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(-9223372036854775808L)),
            ],
          )
          true
        }
        (@lib.Instruction::I64GtS, Some(@lib.I64(raw))) if raw ==
          9223372036854775806L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(9223372036854775807L)),
            ],
          )
          true
        }
        (@lib.Instruction::I64LeS, Some(@lib.I64(raw))) if raw ==
          9223372036854775806L => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            [
              lhs_id,
              @ir.hot_build_const_i64(func, @lib.I64(9223372036854775807L)),
            ],
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_optimize_if_condition(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If if node.child_count == 3 => ()
    _ => return false
  }
  if optimize_instructions_try_collapse_duplicate_then_branch(
      ctx, func, dead, node_id,
    ) {
    return true
  }
  let cond_id = func.children[node.child_base]
  let then_region = func.children[node.child_base + 1]
  let else_region = func.children[node.child_base + 2]
  let flip_if = fn(next_cond : Int) -> Bool {
    match optimize_instructions_i32_const(func, dead, next_cond) {
      Some(@lib.I32(raw)) if raw == 0 => return false
      _ => ()
    }
    match optimize_instructions_i64_const(func, dead, next_cond) {
      Some(@lib.I64(raw)) if raw == 0L => return false
      _ => ()
    }
    ignore(
      @ir.hot_replace_child_span(func, node_id, [
        next_cond, else_region, then_region,
      ]),
    )
    pass_mark_mutated(ctx, func)
    true
  }
  let cond_instr = match @ir.hot_node_exact_instr(func, cond_id) {
    Some(instr) => instr
    None => {
      if optimize_instructions_try_invert_nested_if_condition(
          ctx, func, dead, node_id, cond_id, then_region, else_region,
        ) {
        return true
      }
      return optimize_instructions_try_negate_nested_if_condition_to_eqz(
        ctx, func, dead, node_id, cond_id, else_region,
      )
    }
  }
  let direct_rewrite = match cond_instr {
    @lib.Instruction::I32Ne => {
      if @ir.hot_child_count(func, cond_id) != 2 {
        return false
      }
      let lhs_id = @ir.hot_child_get(func, cond_id, 0)
      let rhs_id = @ir.hot_child_get(func, cond_id, 1)
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw == 0 &&
          OiI32ValueFact::proves_node_i32_value(func, lhs_id) => {
          @ir.hot_child_set(func, node_id, 0, lhs_id)
          pass_mark_mutated(ctx, func)
          true
        }
        _ => false
      }
    }
    @lib.Instruction::I32Eq => {
      if @ir.hot_child_count(func, cond_id) != 2 {
        return false
      }
      let lhs_id = @ir.hot_child_get(func, cond_id, 0)
      let rhs_id = @ir.hot_child_get(func, cond_id, 1)
      let operand_id = match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(0)), _) => Some(rhs_id)
        (_, Some(@lib.I32(0))) => Some(lhs_id)
        _ => None
      }
      match operand_id {
        Some(operand_id) if OiI32ValueFact::proves_node_i32_value(
            func, operand_id,
          ) =>
          if @ir.hot_node_is_live(func, else_region) {
            flip_if(operand_id)
          } else {
            optimize_instructions_replace_with_exact_unary(
              ctx,
              func,
              cond_id,
              @lib.Instruction::i32_eqz(),
              operand_id,
            )
            true
          }
        Some(_) => false
        None => false
      }
    }
    @lib.Instruction::I32Eqz => {
      if !@ir.hot_node_is_live(func, else_region) ||
        @ir.hot_child_count(func, cond_id) != 1 {
        return false
      }
      let operand_id = @ir.hot_child_get(func, cond_id, 0)
      if !OiI32ValueFact::proves_node_i32_value(func, operand_id) {
        return false
      }
      flip_if(operand_id)
    }
    _ => false
  }
  if direct_rewrite {
    return true
  }
  if optimize_instructions_try_invert_nested_if_condition(
      ctx, func, dead, node_id, cond_id, then_region, else_region,
    ) {
    return true
  }
  optimize_instructions_try_negate_nested_if_condition_to_eqz(
    ctx, func, dead, node_id, cond_id, else_region,
  )
}

///|
fn optimize_instructions_try_wrap_boolean_if_value_in_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if @ir.hot_node_result_arity(func, node_id) != 1 {
    return false
  }
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None => return false
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_region) != 1 ||
    @ir.hot_region_root_count(func, else_region) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let else_root = @ir.hot_region_get(func, else_region, 0)
  let plain_boolean_const_arms = match
    (
      optimize_instructions_i32_const(func, dead, then_root),
      optimize_instructions_i32_const(func, dead, else_root),
    ) {
    (Some(@lib.I32(0)), Some(@lib.I32(1)))
    | (Some(@lib.I32(1)), Some(@lib.I32(0))) => true
    _ => false
  }
  if plain_boolean_const_arms {
    return false
  }
  if OiBooleanConstantTreeFact::proves_node_boolean_tree(func, dead, then_root) &&
    OiBooleanConstantTreeFact::proves_node_boolean_tree(func, dead, else_root) {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  if @ir.node_use_count(use_def, node_id) != 1 {
    return false
  }
  let use_sites = @ir.node_use_sites_borrowed(use_def, node_id)
  if use_sites.length() != 1 {
    return false
  }
  let use_site = use_sites[0]
  if use_site.user == -1 {
    return false
  }
  match use_site.kind {
    @ir.HotUseSlotKind::ChildUseSlot => ()
    @ir.HotUseSlotKind::RootUseSlot => return false
  }
  let use_user = @ir.hot_node_get(func, use_site.user)
  match use_user.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => return false
  }
  let neg_then = match
    optimize_instructions_negate_boolean_expr_recursive(func, dead, then_root) {
    Some(node) => node
    None => return false
  }
  let neg_else = match
    optimize_instructions_negate_boolean_expr_recursive(func, dead, else_root) {
    Some(node) => node
    None => return false
  }
  @ir.hot_region_replace_body(func, then_region, [neg_then])
  @ir.hot_region_replace_body(func, else_region, [neg_else])
  let wrapped = @ir.hot_build_unary(func, @lib.ValType::i32(), node_id)
  @ir.hot_node_exact_instr_set(func, wrapped, @lib.Instruction::i32_eqz())
  @ir.hot_child_set(func, use_site.user, use_site.slot, wrapped)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_invert_nested_if_condition(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  cond_id : Int,
  then_region : Int,
  else_region : Int,
) -> Bool {
  if !@ir.hot_node_is_live(func, else_region) {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  if @ir.node_use_count(use_def, cond_id) != 1 {
    return false
  }
  match @ir.hot_node_get(func, cond_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_then = @ir.hot_region_then_ref(func, cond_id)
  let cond_else = match @ir.hot_region_else_ref(func, cond_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, cond_then) != 1 ||
    @ir.hot_region_root_count(func, cond_else) != 1 {
    return false
  }
  let neg_then = match
    optimize_instructions_negate_boolean_expr(
      func,
      dead,
      @ir.hot_region_get(func, cond_then, 0),
    ) {
    Some(node) => node
    None => return false
  }
  let neg_else = match
    optimize_instructions_negate_boolean_expr(
      func,
      dead,
      @ir.hot_region_get(func, cond_else, 0),
    ) {
    Some(node) => node
    None => return false
  }
  @ir.hot_region_replace_body(func, cond_then, [neg_then])
  @ir.hot_region_replace_body(func, cond_else, [neg_else])
  ignore(
    @ir.hot_replace_child_span(func, node_id, [
      cond_id, else_region, then_region,
    ]),
  )
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_negate_nested_if_condition_to_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  cond_id : Int,
  else_region : Int,
) -> Bool {
  if @ir.hot_node_is_live(func, else_region) {
    return false
  }
  let use_def = pass_require_use_def(ctx, func)
  if !optimize_instructions_boolean_tree_if_nodes_are_unshared(
      func, dead, use_def, cond_id,
    ) {
    return false
  }
  match @ir.hot_node_get(func, cond_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let cond_then = @ir.hot_region_then_ref(func, cond_id)
  let cond_else = match @ir.hot_region_else_ref(func, cond_id) {
    Some(region) => region
    None => return false
  }
  if @ir.hot_region_root_count(func, cond_then) != 1 ||
    @ir.hot_region_root_count(func, cond_else) != 1 {
    return false
  }
  let neg_then = match
    optimize_instructions_negate_boolean_expr_recursive(
      func,
      dead,
      @ir.hot_region_get(func, cond_then, 0),
    ) {
    Some(node) => node
    None => return false
  }
  let neg_else = match
    optimize_instructions_negate_boolean_expr_recursive(
      func,
      dead,
      @ir.hot_region_get(func, cond_else, 0),
    ) {
    Some(node) => node
    None => return false
  }
  @ir.hot_region_replace_body(func, cond_then, [neg_then])
  @ir.hot_region_replace_body(func, cond_else, [neg_else])
  let wrapped = @ir.hot_build_unary(func, @lib.ValType::i32(), cond_id)
  @ir.hot_node_exact_instr_set(func, wrapped, @lib.Instruction::i32_eqz())
  @ir.hot_child_set(func, node_id, 0, wrapped)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_const_memory_size_exact(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(@lib.I32(raw)) if raw >= 0 => Some(raw)
        @ir.HotConstPayload::I64Const(@lib.I64(raw)) if raw >= 0L &&
          raw <= 2147483647L => Some(raw.to_int())
        _ => None
      }
    _ => None
  }
}

///|
fn optimize_instructions_const_memory_size(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(raw)) if raw >= 0 => Some(raw)
    _ =>
      match optimize_instructions_i64_const(func, dead, node_id) {
        Some(@lib.I64(raw)) if raw >= 0L && raw <= 2147483647L =>
          Some(raw.to_int())
        _ => optimize_instructions_const_memory_size_exact(func, node_id)
      }
  }
}

///|
fn optimize_instructions_i32_const_for_memory_fill(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I32? {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(value) => Some(value)
    None => {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::Const =>
          match @ir.hot_const_get(func, node.imm0) {
            @ir.HotConstPayload::I32Const(value) => Some(value)
            _ => None
          }
        _ => None
      }
    }
  }
}

///|
fn optimize_instructions_memarg_for_mem_idx(mem_idx : Int) -> @lib.MemArg {
  @lib.MemArg::new(
    @lib.U32(0),
    Some(@lib.MemIdx::new(mem_idx.reinterpret_as_uint())),
    @lib.U64(0),
  )
}

///|
priv struct OiStateWriteSetFact {
  local_writes : Array[Int]
  global_writes : Array[Int]
}

///|
priv struct OiLeftFallthroughInputFact {
  fallthrough_id : Int
  after_value_effect_mask : UInt
  after_value_write_mask : UInt
  after_value_state_writes : OiStateWriteSetFact
  unsupported_after_value_control : Bool
}

///|
priv struct OiRightFallthroughInputFact {
  fallthrough_id : Int
  prefix_effect_mask : UInt
  prefix_write_mask : UInt
  prefix_state_writes : OiStateWriteSetFact
  unsupported_prefix_control : Bool
  peeled_local_tee : Bool
}

///|
priv struct OiInterveningEffectFact {
  effect_mask : UInt
  write_mask : UInt
  state_writes : OiStateWriteSetFact
  unsupported_control : Bool
}

///|
priv struct OiSubtreeReorderEffectFact {
  effect_mask : UInt
  read_mask : UInt
  write_mask : UInt
  state_writes : OiStateWriteSetFact
  carries_control : Bool
  disrupts : Bool
  has_side_effect : Bool
}

///|
priv struct OiLeadingOperandSwapFact {
  left_in_bounds : Bool
  right_in_bounds : Bool
  left_effects : OiSubtreeReorderEffectFact
  right_effects : OiSubtreeReorderEffectFact
}

///|
priv struct OiNodeEffectPurityFact {
  effect_mask : UInt
  mask_is_pure : Bool
}

///|
priv struct OiConsecutiveInputEqualityFact {
  left_fallthrough_id : Int
  right_fallthrough_id : Int
  matching_tee_and_get : Bool
  matching_pure_scalar_tree : Bool
  matching_stable_state_read : Bool
  matching_stable_state_scalar_tree : Bool
  matching_stable_memory_read : Bool
  matching_right_local_tee_fallthrough : Bool
  intervening_effects_interfere : Bool
}

///|
fn OiStateWriteSetFact::empty() -> OiStateWriteSetFact {
  { local_writes: [], global_writes: [] }
}

///|
fn OiStateWriteSetFact::add_local(
  self : OiStateWriteSetFact,
  local_idx : Int,
) -> Unit {
  for value in self.local_writes {
    if value == local_idx {
      return
    }
  }
  self.local_writes.push(local_idx)
}

///|
fn OiStateWriteSetFact::add_global(
  self : OiStateWriteSetFact,
  global_idx : Int,
) -> Unit {
  for value in self.global_writes {
    if value == global_idx {
      return
    }
  }
  self.global_writes.push(global_idx)
}

///|
fn OiStateWriteSetFact::append_from(
  self : OiStateWriteSetFact,
  other : OiStateWriteSetFact,
) -> Unit {
  for local_idx in other.local_writes {
    self.add_local(local_idx)
  }
  for global_idx in other.global_writes {
    self.add_global(global_idx)
  }
}

///|
fn OiStateWriteSetFact::writes_local(
  self : OiStateWriteSetFact,
  local_idx : Int,
) -> Bool {
  for value in self.local_writes {
    if value == local_idx {
      return true
    }
  }
  false
}

///|
fn OiStateWriteSetFact::writes_global(
  self : OiStateWriteSetFact,
  global_idx : Int,
) -> Bool {
  for value in self.global_writes {
    if value == global_idx {
      return true
    }
  }
  false
}

///|
fn OiStateWriteSetFact::has_local_writes(self : OiStateWriteSetFact) -> Bool {
  self.local_writes.length() != 0
}

///|
fn OiStateWriteSetFact::has_global_writes(self : OiStateWriteSetFact) -> Bool {
  self.global_writes.length() != 0
}

///|
fn OiStateWriteSetFact::from_value_subtree(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiStateWriteSetFact {
  // Binaryen's `EffectAnalyzer::invalidates` reasons about precise local/global
  // locations even though coarse HOT effect bits conflate reads and writes.
  // Keep the represented OI subset as a fact so fallthrough-prefix and
  // after-value equality paths share the same source-backed write-set proof.
  let fact = OiStateWriteSetFact::empty()
  fn walk(id : Int) -> Unit {
    let node = @ir.hot_node_get(func, id)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => fact.add_local(node.imm0)
      @ir.HotOp::GlobalSet => fact.add_global(node.imm0)
      _ => ()
    }
    for slot = 0; slot < @ir.hot_child_count(func, id); slot = slot + 1 {
      walk(@ir.hot_child_get(func, id, slot))
    }
  }
  walk(node_id)
  fact
}

///|
fn OiNodeEffectPurityFact::from_mask(mask : UInt) -> OiNodeEffectPurityFact {
  // Shared OI view of Binaryen `EffectAnalyzer(...).hasUnremovableSideEffects()`
  // negative queries: callers that only need the existing HOT effect-mask
  // proof should record that as a fact instead of reading raw masks directly.
  { effect_mask: mask, mask_is_pure: @ir.effects_is_pure(mask) }
}

///|
fn OiNodeEffectPurityFact::from_node_masks(
  node_masks : Array[UInt],
  node_id : Int,
) -> OiNodeEffectPurityFact {
  if node_id < 0 || node_id >= node_masks.length() {
    { effect_mask: 0U, mask_is_pure: false }
  } else {
    OiNodeEffectPurityFact::from_mask(node_masks[node_id])
  }
}

///|
fn OiNodeEffectPurityFact::proves_pure(self : OiNodeEffectPurityFact) -> Bool {
  ignore(self.effect_mask)
  self.mask_is_pure
}

///|
fn OiSubtreeReorderEffectFact::empty() -> OiSubtreeReorderEffectFact {
  {
    effect_mask: 0U,
    read_mask: 0U,
    write_mask: 0U,
    state_writes: OiStateWriteSetFact::empty(),
    carries_control: false,
    disrupts: false,
    has_side_effect: false,
  }
}

///|
fn OiSubtreeReorderEffectFact::read_effect_mask() -> UInt {
  @ir.EFFECT_MASK_LOCAL_STATE |
  @ir.EFFECT_MASK_GLOBAL_STATE |
  @ir.EFFECT_MASK_MEMORY_READ |
  @ir.EFFECT_MASK_TABLE_READ
}

///|
fn OiSubtreeReorderEffectFact::write_mask_from_effects(
  effect_mask : UInt,
  state_writes : OiStateWriteSetFact,
) -> UInt {
  // Binaryen's `EffectAnalyzer::invalidates` separates reads from writes. HOT's
  // coarse effect masks already identify memory/table writes and calls, while
  // local/global writes need the precise `OiStateWriteSetFact` subtree walk.
  let mut writes = 0U
  if (effect_mask & (@ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_CALL)) != 0U {
    writes = writes | @ir.EFFECT_MASK_MEMORY_READ
  }
  if (effect_mask & (@ir.EFFECT_MASK_TABLE_WRITE | @ir.EFFECT_MASK_CALL)) != 0U {
    writes = writes | @ir.EFFECT_MASK_TABLE_READ
  }
  if (effect_mask & @ir.EFFECT_MASK_CALL) != 0U ||
    state_writes.has_global_writes() {
    writes = writes | @ir.EFFECT_MASK_GLOBAL_STATE
  }
  if state_writes.has_local_writes() {
    writes = writes | @ir.EFFECT_MASK_LOCAL_STATE
  }
  writes
}

///|
fn OiSubtreeReorderEffectFact::from_node(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> OiSubtreeReorderEffectFact {
  // Source-backed subset of Binaryen v130 `EffectAnalyzer::orderedBefore` /
  // `invalidates` used by OI operand reordering and consecutive-input equality:
  // represent reorderable read regions, precise local/global writes, coarse
  // memory/table/call writes, control blockers, and trap/throw side-effect
  // hazards as fact fields instead of recomputing scanner-local booleans.
  let effect_mask = node_masks[node_id]
  let state_writes = OiStateWriteSetFact::from_value_subtree(func, node_id)
  let write_mask = OiSubtreeReorderEffectFact::write_mask_from_effects(
    effect_mask, state_writes,
  )
  {
    effect_mask,
    read_mask: effect_mask & OiSubtreeReorderEffectFact::read_effect_mask(),
    write_mask,
    state_writes,
    carries_control: (effect_mask & @ir.EFFECT_MASK_CONTROL) != 0U,
    disrupts: (effect_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)) !=
    0U,
    has_side_effect: write_mask != 0U ||
    (effect_mask & @ir.EFFECT_MASK_THROW) != 0U,
  }
}

///|
fn OiSubtreeReorderEffectFact::can_swap_with(
  self : OiSubtreeReorderEffectFact,
  other : OiSubtreeReorderEffectFact,
) -> Bool {
  if self.carries_control || other.carries_control {
    return false
  }
  let region_conflict = ((self.read_mask | self.write_mask) & other.write_mask) !=
    0U ||
    ((other.read_mask | other.write_mask) & self.write_mask) != 0U
  if region_conflict {
    return false
  }
  if (self.disrupts && other.has_side_effect) ||
    (other.disrupts && self.has_side_effect) {
    return false
  }
  true
}

///|
fn optimize_instructions_mask_without_local_state(mask : UInt) -> UInt {
  if (mask & @ir.EFFECT_MASK_LOCAL_STATE) != 0U {
    mask ^ @ir.EFFECT_MASK_LOCAL_STATE
  } else {
    mask
  }
}

///|
fn optimize_instructions_mask_without_global_state(mask : UInt) -> UInt {
  if (mask & @ir.EFFECT_MASK_GLOBAL_STATE) != 0U {
    mask ^ @ir.EFFECT_MASK_GLOBAL_STATE
  } else {
    mask
  }
}

///|
priv struct OiPureScalarEqualTreeShellFact {
  branchless_scalar_shell : Bool
}

///|
fn OiPureScalarEqualTreeShellFact::from_op(
  op : @ir.HotOp,
) -> OiPureScalarEqualTreeShellFact {
  // Source-mapped subset of Binaryen v130 `ExpressionAnalyzer::equal` used by
  // OI's consecutive-input equality facts: branchless scalar expression shells
  // whose children are recursively deterministic under the enclosing ordered-
  // effects check.
  match op {
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => { branchless_scalar_shell: true }
    _ => { branchless_scalar_shell: false }
  }
}

///|
fn OiPureScalarEqualTreeShellFact::proves_shell(
  self : OiPureScalarEqualTreeShellFact,
) -> Bool {
  self.branchless_scalar_shell
}

///|
priv struct OiStableStateReadEqualityFact {
  matching_memory_size : Bool
  matching_table_size : Bool
  same_index : Bool
}

///|
fn OiStableStateReadEqualityFact::from_nodes(
  left : @ir.HotNode,
  right : @ir.HotNode,
) -> OiStableStateReadEqualityFact {
  // Binaryen v130 `areConsecutiveInputsEqual` reaches
  // `ExpressionAnalyzer::equal` after fallthrough peeling. Deterministic state
  // reads with the same index compare equal there, but only after the enclosing
  // equality fact has checked that intervening effects are not ordered before
  // the right read. Keep this fact separate from pure scalar equality so state
  // reads remain visible as effect-sensitive equality, not pure values.
  match (left.op, right.op) {
    (@ir.HotOp::MemorySize, @ir.HotOp::MemorySize) =>
      {
        matching_memory_size: true,
        matching_table_size: false,
        same_index: left.imm0 == right.imm0,
      }
    (@ir.HotOp::TableSize, @ir.HotOp::TableSize) =>
      {
        matching_memory_size: false,
        matching_table_size: true,
        same_index: left.imm0 == right.imm0,
      }
    _ =>
      {
        matching_memory_size: false,
        matching_table_size: false,
        same_index: false,
      }
  }
}

///|
fn OiStableStateReadEqualityFact::proves_equal(
  self : OiStableStateReadEqualityFact,
) -> Bool {
  self.same_index && (self.matching_memory_size || self.matching_table_size)
}

///|
fn optimize_instructions_scalar_tree_metadata_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  left : @ir.HotNode,
  right : @ir.HotNode,
) -> Bool {
  if left.op != right.op ||
    !OiPureScalarEqualTreeShellFact::from_op(left.op).proves_shell() ||
    left.ty != right.ty ||
    left.flags != right.flags ||
    left.imm1 != right.imm1 ||
    left.child_count != right.child_count {
    return false
  }
  match
    (
      @ir.hot_node_exact_instr(func, left_id),
      @ir.hot_node_exact_instr(func, right_id),
    ) {
    (Some(left_instr), Some(right_instr)) => left_instr == right_instr
    _ => left.imm0 == right.imm0
  }
}

///|
priv struct OiScalarTreeEqualityFact {
  matching_local_get_leaf : Bool
  matching_global_get_leaf : Bool
  matching_const_leaf : Bool
  matching_stable_state_read_leaf : Bool
  matching_branchless_scalar_shell : Bool
  children_equal : Bool
  contains_stable_state_read : Bool
}

///|
fn OiScalarTreeEqualityFact::empty() -> OiScalarTreeEqualityFact {
  {
    matching_local_get_leaf: false,
    matching_global_get_leaf: false,
    matching_const_leaf: false,
    matching_stable_state_read_leaf: false,
    matching_branchless_scalar_shell: false,
    children_equal: false,
    contains_stable_state_read: false,
  }
}

///|
fn OiScalarTreeEqualityFact::from_nodes(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  include_stable_state_read? : Bool = false,
  depth? : Int = 0,
) -> OiScalarTreeEqualityFact {
  // Source-backed subset of Binaryen v130 `ExpressionAnalyzer::equal` used by
  // OI's equality facts. Keep leaf classes, branchless scalar-shell equality,
  // and deterministic memory/table-size reads as explicit fields so callers can
  // distinguish pure equality from effect-sensitive equality that still needs an
  // enclosing `orderedBefore` / invalidation check.
  if depth > 16 {
    return OiScalarTreeEqualityFact::empty()
  }
  let left = @ir.hot_node_get(func, left_id)
  let right = @ir.hot_node_get(func, right_id)
  match (left.op, right.op) {
    (@ir.HotOp::LocalGet, @ir.HotOp::LocalGet) if left.imm0 == right.imm0 =>
      return {
        matching_local_get_leaf: true,
        matching_global_get_leaf: false,
        matching_const_leaf: false,
        matching_stable_state_read_leaf: false,
        matching_branchless_scalar_shell: false,
        children_equal: false,
        contains_stable_state_read: false,
      }
    (@ir.HotOp::GlobalGet, @ir.HotOp::GlobalGet) if left.imm0 == right.imm0 =>
      return {
        matching_local_get_leaf: false,
        matching_global_get_leaf: true,
        matching_const_leaf: false,
        matching_stable_state_read_leaf: false,
        matching_branchless_scalar_shell: false,
        children_equal: false,
        contains_stable_state_read: false,
      }
    (@ir.HotOp::Const, @ir.HotOp::Const) if @ir.hot_const_get(func, left.imm0) ==
      @ir.hot_const_get(func, right.imm0) =>
      return {
        matching_local_get_leaf: false,
        matching_global_get_leaf: false,
        matching_const_leaf: true,
        matching_stable_state_read_leaf: false,
        matching_branchless_scalar_shell: false,
        children_equal: false,
        contains_stable_state_read: false,
      }
    _ => ()
  }
  if include_stable_state_read &&
    OiStableStateReadEqualityFact::from_nodes(left, right).proves_equal() {
    return {
      matching_local_get_leaf: false,
      matching_global_get_leaf: false,
      matching_const_leaf: false,
      matching_stable_state_read_leaf: true,
      matching_branchless_scalar_shell: false,
      children_equal: false,
      contains_stable_state_read: true,
    }
  }
  if !optimize_instructions_scalar_tree_metadata_equal(
      func, left_id, right_id, left, right,
    ) {
    return OiScalarTreeEqualityFact::empty()
  }
  let mut children_equal = true
  let mut contains_stable_state_read = false
  for slot = 0; slot < left.child_count; slot = slot + 1 {
    let child_fact = OiScalarTreeEqualityFact::from_nodes(
      func,
      @ir.hot_child_get(func, left_id, slot),
      @ir.hot_child_get(func, right_id, slot),
      include_stable_state_read~,
      depth=depth + 1,
    )
    if !child_fact.proves_equal() {
      children_equal = false
    }
    if child_fact.contains_stable_state_read {
      contains_stable_state_read = true
    }
  }
  {
    matching_local_get_leaf: false,
    matching_global_get_leaf: false,
    matching_const_leaf: false,
    matching_stable_state_read_leaf: false,
    matching_branchless_scalar_shell: true,
    children_equal,
    contains_stable_state_read,
  }
}

///|
fn OiScalarTreeEqualityFact::proves_equal(
  self : OiScalarTreeEqualityFact,
) -> Bool {
  self.matching_local_get_leaf ||
  self.matching_global_get_leaf ||
  self.matching_const_leaf ||
  self.matching_stable_state_read_leaf ||
  (self.matching_branchless_scalar_shell && self.children_equal)
}

///|
fn OiScalarTreeEqualityFact::proves_pure_equal(
  self : OiScalarTreeEqualityFact,
) -> Bool {
  self.proves_equal() && !self.contains_stable_state_read
}

///|
fn OiScalarTreeEqualityFact::proves_stable_state_scalar_equal(
  self : OiScalarTreeEqualityFact,
) -> Bool {
  self.proves_equal() && self.contains_stable_state_read
}

///|
priv struct OiStableMemoryReadEqualityFact {
  matching_load : Bool
  matching_atomic_load : Bool
  same_instruction : Bool
  address_fact : OiScalarTreeEqualityFact
}

///|
fn OiStableMemoryReadEqualityFact::empty() -> OiStableMemoryReadEqualityFact {
  {
    matching_load: false,
    matching_atomic_load: false,
    same_instruction: false,
    address_fact: OiScalarTreeEqualityFact::empty(),
  }
}

///|
fn OiStableMemoryReadEqualityFact::exact_instr_is_atomic_load(
  instr : @lib.Instruction,
) -> Bool {
  match instr {
    @lib.Instruction::I32AtomicLoad(_)
    | @lib.Instruction::I64AtomicLoad(_)
    | @lib.Instruction::I32AtomicLoad8U(_)
    | @lib.Instruction::I32AtomicLoad16U(_)
    | @lib.Instruction::I64AtomicLoad8U(_)
    | @lib.Instruction::I64AtomicLoad16U(_)
    | @lib.Instruction::I64AtomicLoad32U(_) => true
    _ => false
  }
}

///|
fn OiStableMemoryReadEqualityFact::from_nodes(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
) -> OiStableMemoryReadEqualityFact {
  // Binaryen v130 `areConsecutiveInputsEqual` delegates to
  // `ExpressionAnalyzer::equal` after fallthrough peeling, then separately asks
  // `EffectAnalyzer::orderedBefore(effects(right))` whether intervening effects
  // can change the right read. Model the represented load subset as an explicit
  // effect-sensitive fact: same load/atomic-load instruction, same access
  // metadata, and an `OiScalarTreeEqualityFact` address proof for pure scalar
  // trees plus deterministic state-read leaves. The enclosing equality fact
  // still owns the memory/state-write interference check, so store/grow prefixes
  // keep the copy live.
  let left = @ir.hot_node_get(func, left_id)
  let right = @ir.hot_node_get(func, right_id)
  if left.child_count != 1 || right.child_count != 1 {
    return OiStableMemoryReadEqualityFact::empty()
  }
  match
    (
      @ir.hot_node_exact_instr(func, left_id),
      @ir.hot_node_exact_instr(func, right_id),
    ) {
    (Some(left_instr), Some(right_instr)) if left_instr == right_instr => {
      let mut matching_load = false
      let mut matching_atomic_load = false
      match (left.op, right.op) {
        (@ir.HotOp::Load, @ir.HotOp::Load) => matching_load = true
        (@ir.HotOp::Atomic, @ir.HotOp::Atomic) =>
          matching_atomic_load = OiStableMemoryReadEqualityFact::exact_instr_is_atomic_load(
            left_instr,
          )
        _ => ()
      }
      if !matching_load && !matching_atomic_load {
        return OiStableMemoryReadEqualityFact::empty()
      }
      {
        matching_load,
        matching_atomic_load,
        same_instruction: true,
        address_fact: OiScalarTreeEqualityFact::from_nodes(
          func,
          @ir.hot_child_get(func, left_id, 0),
          @ir.hot_child_get(func, right_id, 0),
          include_stable_state_read=true,
        ),
      }
    }
    _ => OiStableMemoryReadEqualityFact::empty()
  }
}

///|
fn OiStableMemoryReadEqualityFact::proves_equal(
  self : OiStableMemoryReadEqualityFact,
) -> Bool {
  self.same_instruction &&
  (self.matching_load || self.matching_atomic_load) &&
  self.address_fact.proves_equal()
}

///|
fn optimize_instructions_left_fallthrough_input_for_equality(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
  right_fallthrough_id : Int,
) -> OiLeftFallthroughInputFact {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block if node.child_count > 0 =>
      optimize_instructions_left_fallthrough_input_for_equality(
        func,
        node_masks,
        @ir.hot_child_get(func, node_id, node.child_count - 1),
        right_fallthrough_id,
      )
    @ir.HotOp::LocalTee if node.child_count > 0 => {
      let right = @ir.hot_node_get(func, right_fallthrough_id)
      match right.op {
        @ir.HotOp::LocalGet if node.imm0 == right.imm0 =>
          return {
            fallthrough_id: node_id,
            after_value_effect_mask: 0U,
            after_value_write_mask: 0U,
            after_value_state_writes: OiStateWriteSetFact::empty(),
            unsupported_after_value_control: false,
          }
        _ => ()
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      let nested = optimize_instructions_left_fallthrough_input_for_equality(
        func, node_masks, child_id, right_fallthrough_id,
      )
      let state_writes = OiStateWriteSetFact::empty()
      state_writes.append_from(nested.after_value_state_writes)
      state_writes.add_local(node.imm0)
      {
        fallthrough_id: nested.fallthrough_id,
        after_value_effect_mask: nested.after_value_effect_mask |
        @ir.EFFECT_MASK_LOCAL_STATE,
        after_value_write_mask: nested.after_value_write_mask |
        @ir.EFFECT_MASK_LOCAL_STATE,
        after_value_state_writes: state_writes,
        unsupported_after_value_control: nested.unsupported_after_value_control,
      }
    }
    @ir.HotOp::BrIf =>
      // Binaryen v130 `areConsecutiveInputsEqual` peels a value-carrying left
      // `br_if` to its payload and records the condition as an after-value
      // interfering effect. Keep Starshine's equality fact closed here until
      // value-carrying `br_if` operands can pass HOT/pass verification; see
      // docs/wiki/raw/research/1557-2026-07-07-optimize-instructions-br-if-equality-blocker.md.
      {
        fallthrough_id: node_id,
        after_value_effect_mask: 0U,
        after_value_write_mask: 0U,
        after_value_state_writes: OiStateWriteSetFact::empty(),
        unsupported_after_value_control: true,
      }
    _ =>
      {
        fallthrough_id: node_id,
        after_value_effect_mask: 0U,
        after_value_write_mask: 0U,
        after_value_state_writes: OiStateWriteSetFact::empty(),
        unsupported_after_value_control: false,
      }
  }
}

///|
fn optimize_instructions_right_fallthrough_input_for_equality(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> OiRightFallthroughInputFact {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block if node.child_count > 0 => {
      let mut prefix_effect_mask = 0U
      let mut prefix_write_mask = 0U
      let prefix_state_writes = OiStateWriteSetFact::empty()
      for slot = 0; slot < node.child_count - 1; slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        let child_mask = node_masks[child_id]
        if (child_mask & @ir.EFFECT_MASK_CONTROL) != 0U {
          return {
            fallthrough_id: node_id,
            prefix_effect_mask: 0U,
            prefix_write_mask: 0U,
            prefix_state_writes: OiStateWriteSetFact::empty(),
            unsupported_prefix_control: true,
            peeled_local_tee: false,
          }
        }
        let child_effect_fact = OiSubtreeReorderEffectFact::from_node(
          func, node_masks, child_id,
        )
        prefix_effect_mask = prefix_effect_mask | child_effect_fact.effect_mask
        prefix_write_mask = prefix_write_mask | child_effect_fact.write_mask
        prefix_state_writes.append_from(child_effect_fact.state_writes)
      }
      let nested = optimize_instructions_right_fallthrough_input_for_equality(
        func,
        node_masks,
        @ir.hot_child_get(func, node_id, node.child_count - 1),
      )
      prefix_state_writes.append_from(nested.prefix_state_writes)
      {
        fallthrough_id: nested.fallthrough_id,
        prefix_effect_mask: prefix_effect_mask | nested.prefix_effect_mask,
        prefix_write_mask: prefix_write_mask | nested.prefix_write_mask,
        prefix_state_writes,
        unsupported_prefix_control: nested.unsupported_prefix_control,
        peeled_local_tee: nested.peeled_local_tee,
      }
    }
    @ir.HotOp::LocalTee if node.child_count > 0 => {
      // Binaryen v130 `areConsecutiveInputsEqual` peels the right-side
      // immediate fallthrough with `FallthroughBehavior::AllowTeeBrIf`, so a
      // right `local.tee` contributes its value child to the equality proof. The
      // tee write is not an intervening prefix effect for the right value; it is
      // preserved later when the original operand is dropped.
      let nested = optimize_instructions_right_fallthrough_input_for_equality(
        func,
        node_masks,
        @ir.hot_child_get(func, node_id, 0),
      )
      {
        fallthrough_id: nested.fallthrough_id,
        prefix_effect_mask: nested.prefix_effect_mask,
        prefix_write_mask: nested.prefix_write_mask,
        prefix_state_writes: nested.prefix_state_writes,
        unsupported_prefix_control: nested.unsupported_prefix_control,
        peeled_local_tee: true,
      }
    }
    _ =>
      {
        fallthrough_id: node_id,
        prefix_effect_mask: 0U,
        prefix_write_mask: 0U,
        prefix_state_writes: OiStateWriteSetFact::empty(),
        unsupported_prefix_control: false,
        peeled_local_tee: false,
      }
  }
}

///|
fn OiInterveningEffectFact::from_fallthrough_facts(
  left : OiLeftFallthroughInputFact,
  right : OiRightFallthroughInputFact,
) -> OiInterveningEffectFact {
  let state_writes = OiStateWriteSetFact::empty()
  state_writes.append_from(left.after_value_state_writes)
  state_writes.append_from(right.prefix_state_writes)
  {
    effect_mask: left.after_value_effect_mask | right.prefix_effect_mask,
    write_mask: left.after_value_write_mask | right.prefix_write_mask,
    state_writes,
    unsupported_control: left.unsupported_after_value_control ||
    right.unsupported_prefix_control,
  }
}

///|
fn OiInterveningEffectFact::ordered_before_right_fallthrough(
  self : OiInterveningEffectFact,
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  right_id : Int,
) -> Bool {
  // Represented subset of Binaryen v130
  // `EffectAnalyzer::orderedBefore(effects(right))` / `invalidates` used by
  // OI consecutive-input equality. Coarse effect bits prove memory/table/call
  // interference, while `OiStateWriteSetFact` proves exact local/global misses
  // so `local.get $x` can be reused across writes to other locals and
  // `global.get $x` can be reused across non-call writes to other globals.
  if self.unsupported_control {
    return true
  }
  let right_effect_fact = OiSubtreeReorderEffectFact::from_node(
    func, node_masks, right_id,
  )
  let right_mask = right_effect_fact.effect_mask
  let right_write_mask = right_effect_fact.write_mask
  let mut effect_reads = self.effect_mask &
    OiSubtreeReorderEffectFact::read_effect_mask()
  let mut effective_write_mask = self.write_mask
  let mut right_reads = right_effect_fact.read_mask
  let mut effective_right_write_mask = right_write_mask
  let right = @ir.hot_node_get(func, right_id)
  match right.op {
    @ir.HotOp::LocalGet if !self.state_writes.writes_local(right.imm0) => {
      effective_write_mask = optimize_instructions_mask_without_local_state(
        effective_write_mask,
      )
      effect_reads = optimize_instructions_mask_without_local_state(
        effect_reads,
      )
      right_reads = optimize_instructions_mask_without_local_state(right_reads)
      effective_right_write_mask = optimize_instructions_mask_without_local_state(
        effective_right_write_mask,
      )
    }
    @ir.HotOp::GlobalGet if (self.effect_mask & @ir.EFFECT_MASK_CALL) == 0U &&
      !self.state_writes.writes_global(right.imm0) => {
      effective_write_mask = optimize_instructions_mask_without_global_state(
        effective_write_mask,
      )
      effect_reads = optimize_instructions_mask_without_global_state(
        effect_reads,
      )
      right_reads = optimize_instructions_mask_without_global_state(right_reads)
      effective_right_write_mask = optimize_instructions_mask_without_global_state(
        effective_right_write_mask,
      )
    }
    _ => ()
  }
  let region_conflict = (
      (effect_reads | effective_write_mask) & effective_right_write_mask
    ) !=
    0U ||
    ((right_reads | effective_right_write_mask) & effective_write_mask) != 0U
  if region_conflict {
    return true
  }
  let effects_disrupt = (
      self.effect_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)
    ) !=
    0U
  let right_side_effect = right_write_mask != 0U ||
    (right_mask & @ir.EFFECT_MASK_THROW) != 0U
  effects_disrupt && right_side_effect
}

///|
priv struct OiRightLocalTeeFallthroughEqualityFact {
  right_is_local_tee : Bool
  value_matches_left : Bool
}

///|
fn OiRightLocalTeeFallthroughEqualityFact::from_nodes(
  func : @ir.HotFunc,
  left_fallthrough_id : Int,
  right_id : Int,
) -> OiRightLocalTeeFallthroughEqualityFact {
  // Binaryen v130 `areConsecutiveInputsEqual` peels the right operand with
  // `Properties::getImmediateFallthrough(...AllowTeeBrIf)`, which exposes a
  // direct `local.tee`'s value child to `ExpressionAnalyzer::equal`. Keep the
  // currently represented Starshine subset narrow: direct right `local.tee`
  // values that match the left fallthrough by pure scalar equality. The tee
  // write is intentionally not an intervening prefix effect because it happens
  // after the returned value is produced and is preserved when the original
  // right operand is later dropped.
  let right = @ir.hot_node_get(func, right_id)
  match right.op {
    @ir.HotOp::LocalTee if right.child_count == 1 => {
      let value_id = @ir.hot_child_get(func, right_id, 0)
      {
        right_is_local_tee: true,
        value_matches_left: OiScalarTreeEqualityFact::from_nodes(
          func, left_fallthrough_id, value_id,
        ).proves_pure_equal(),
      }
    }
    _ => { right_is_local_tee: false, value_matches_left: false }
  }
}

///|
fn OiRightLocalTeeFallthroughEqualityFact::proves_equal(
  self : OiRightLocalTeeFallthroughEqualityFact,
) -> Bool {
  self.right_is_local_tee && self.value_matches_left
}

///|
fn OiConsecutiveInputEqualityFact::from_adjacent_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
) -> OiConsecutiveInputEqualityFact {
  let effects = pass_require_effects(ctx, func)
  let right_fallthrough = optimize_instructions_right_fallthrough_input_for_equality(
    func,
    effects.node_masks,
    right_id,
  )
  let right_fallthrough_id = right_fallthrough.fallthrough_id
  let left_fallthrough = optimize_instructions_left_fallthrough_input_for_equality(
    func,
    effects.node_masks,
    left_id,
    right_fallthrough_id,
  )
  let left_fallthrough_id = left_fallthrough.fallthrough_id
  let left = @ir.hot_node_get(func, left_fallthrough_id)
  let right = @ir.hot_node_get(func, right_fallthrough_id)
  let matching_tee_and_get = match (left.op, right.op) {
    (@ir.HotOp::LocalTee, @ir.HotOp::LocalGet) => left.imm0 == right.imm0
    _ => false
  }
  let scalar_tree_fact = OiScalarTreeEqualityFact::from_nodes(
    func, left_fallthrough_id, right_fallthrough_id,
  )
  let state_scalar_tree_fact = OiScalarTreeEqualityFact::from_nodes(
    func,
    left_fallthrough_id,
    right_fallthrough_id,
    include_stable_state_read=true,
  )
  let matching_pure_scalar_tree = scalar_tree_fact.proves_pure_equal()
  let matching_stable_state_read = OiStableStateReadEqualityFact::from_nodes(
    left, right,
  ).proves_equal()
  let matching_stable_state_scalar_tree = state_scalar_tree_fact.proves_stable_state_scalar_equal()
  let matching_stable_memory_read = OiStableMemoryReadEqualityFact::from_nodes(
    func, left_fallthrough_id, right_fallthrough_id,
  ).proves_equal()
  let matching_right_local_tee_fallthrough = OiRightLocalTeeFallthroughEqualityFact::from_nodes(
    func, left_fallthrough_id, right_id,
  ).proves_equal()
  let intervening_effect_fact = OiInterveningEffectFact::from_fallthrough_facts(
    left_fallthrough, right_fallthrough,
  )
  let intervening_effects_interfere = intervening_effect_fact.ordered_before_right_fallthrough(
    func,
    effects.node_masks,
    right_fallthrough_id,
  )
  {
    left_fallthrough_id,
    right_fallthrough_id,
    matching_tee_and_get,
    matching_pure_scalar_tree,
    matching_stable_state_read,
    matching_stable_state_scalar_tree,
    matching_stable_memory_read,
    matching_right_local_tee_fallthrough,
    intervening_effects_interfere,
  }
}

///|
fn OiConsecutiveInputEqualityFact::proves_equal(
  self : OiConsecutiveInputEqualityFact,
  func : @ir.HotFunc,
) -> Bool {
  ignore(func)
  ignore(self.left_fallthrough_id)
  ignore(self.right_fallthrough_id)
  if self.intervening_effects_interfere {
    return false
  }
  if self.matching_tee_and_get ||
    self.matching_pure_scalar_tree ||
    self.matching_stable_state_read ||
    self.matching_stable_state_scalar_tree ||
    self.matching_stable_memory_read ||
    self.matching_right_local_tee_fallthrough {
    return true
  }
  false
}

///|
priv struct OiBulkMemoryFact {
  dst_id : Int
  src_or_value_id : Int
  size_id : Int
  size : Int
  dst_mem_idx : Int
  src_mem_idx : Int
}

///|
fn OiBulkMemoryFact::from_copy(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiBulkMemoryFact? {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 3 {
    return None
  }
  let size_id = @ir.hot_child_get(func, node_id, 2)
  let size = match
    optimize_instructions_const_memory_size(func, dead, size_id) {
    Some(size) => size
    None => -1
  }
  Some({
    dst_id: @ir.hot_child_get(func, node_id, 0),
    src_or_value_id: @ir.hot_child_get(func, node_id, 1),
    size_id,
    size,
    dst_mem_idx: node.imm0,
    src_mem_idx: node.imm1,
  })
}

///|
fn OiBulkMemoryFact::from_fill(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiBulkMemoryFact? {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 3 {
    return None
  }
  let size_id = @ir.hot_child_get(func, node_id, 2)
  let size = match
    optimize_instructions_const_memory_size(func, dead, size_id) {
    Some(size) => size
    None => -1
  }
  Some({
    dst_id: @ir.hot_child_get(func, node_id, 0),
    src_or_value_id: @ir.hot_child_get(func, node_id, 1),
    size_id,
    size,
    dst_mem_idx: node.imm0,
    src_mem_idx: node.imm0,
  })
}

///|
fn OiBulkMemoryFact::dst_memarg(self : OiBulkMemoryFact) -> @lib.MemArg {
  optimize_instructions_memarg_for_mem_idx(self.dst_mem_idx)
}

///|
fn OiBulkMemoryFact::src_memarg(self : OiBulkMemoryFact) -> @lib.MemArg {
  optimize_instructions_memarg_for_mem_idx(self.src_mem_idx)
}

///|
fn OiBulkMemoryFact::has_const_size_operand(self : OiBulkMemoryFact) -> Bool {
  self.size_id >= 0 && self.size >= 0
}

///|
fn OiBulkMemoryFact::has_same_memory(self : OiBulkMemoryFact) -> Bool {
  self.dst_mem_idx == self.src_mem_idx
}

///|
fn OiBulkMemoryFact::dest_and_source_are_consecutive_equal_address(
  self : OiBulkMemoryFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  // Binaryen v130 `areConsecutiveInputsEqual` compares adjacent operands via
  // fallthrough facts, plus a deliberate fast path for a fallthrough
  // `local.tee` immediately followed by a matching `local.get`. Starshine keeps
  // this fact intentionally narrower than Binaryen's full effect-interference
  // helper: right-operand peeling and non-matching left `local.tee` peeling carry
  // accumulated intervening effects, including precise local-write ids for the
  // direct local/global-get fallthrough subset and conservative closure for
  // nested pure scalar trees. Equality currently covers matching tee/get,
  // structurally identical scalar trees made of local.get, global.get,
  // constants, unary, binary, compare, and convert nodes, effect-sensitive
  // same-index memory.size/table.size state reads, scalar trees with those
  // deterministic state-read leaves, and same-access load/atomic-load reads
  // whose address proofs include deterministic state-read leaves.
  OiConsecutiveInputEqualityFact::from_adjacent_operands(
    ctx,
    func,
    self.dst_id,
    self.src_or_value_id,
  ).proves_equal(func)
}

///|
fn OiBulkMemoryFact::can_drop_same_address_copy_trap_relaxed(
  self : OiBulkMemoryFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  (ctx.traps_never_happen || ctx.ignore_implicit_traps) &&
  self.has_same_memory() &&
  self.dest_and_source_are_consecutive_equal_address(ctx, func)
}

///|
fn OiBulkMemoryFact::can_drop_zero_size_trap_relaxed(
  self : OiBulkMemoryFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  if !ctx.traps_never_happen && !ctx.ignore_implicit_traps {
    return false
  }
  if self.size == 0 {
    return true
  }
  match optimize_instructions_const_memory_size_exact(func, self.size_id) {
    Some(0) => true
    _ => false
  }
}

///|
priv struct OiTinyMemoryCopyFact {
  size : Int
}

///|
fn OiTinyMemoryCopyFact::from_size(
  ctx : HotPassContext,
  size : Int,
) -> OiTinyMemoryCopyFact? {
  match size {
    1 | 2 | 4 | 8 => Some({ size, })
    16 =>
      // Binaryen v130 `optimizeMemoryCopy` only emits the SIMD 16-byte
      // load/store lane when `shrinkLevel == 0`; higher shrink levels keep the
      // bulk-memory spelling to avoid the extra bytes.
      if ctx.shrink_level == 0 {
        Some({ size, })
      } else {
        None
      }
    _ => None
  }
}

///|
fn OiTinyMemoryCopyFact::load_type(self : OiTinyMemoryCopyFact) -> @lib.ValType {
  match self.size {
    8 => @lib.ValType::i64()
    16 => @lib.ValType::v128()
    _ => @lib.ValType::i32()
  }
}

///|
fn OiTinyMemoryCopyFact::load_instr(
  self : OiTinyMemoryCopyFact,
  memarg : @lib.MemArg,
) -> @lib.Instruction {
  match self.size {
    1 => @lib.Instruction::i32_load8u(memarg)
    2 => @lib.Instruction::i32_load16u(memarg)
    4 => @lib.Instruction::i32_load(memarg)
    8 => @lib.Instruction::i64_load(memarg)
    16 => @lib.Instruction::v128_load(memarg)
    _ => abort("unreachable tiny memory.copy load fact")
  }
}

///|
fn OiTinyMemoryCopyFact::store_instr(
  self : OiTinyMemoryCopyFact,
  memarg : @lib.MemArg,
) -> @lib.Instruction {
  match self.size {
    1 => @lib.Instruction::i32_store8(memarg)
    2 => @lib.Instruction::i32_store16(memarg)
    4 => @lib.Instruction::i32_store(memarg)
    8 => @lib.Instruction::i64_store(memarg)
    16 => @lib.Instruction::v128_store(memarg)
    _ => abort("unreachable tiny memory.copy store fact")
  }
}

///|
fn optimize_instructions_replace_with_store_exact(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  mem_idx : Int,
  address_id : Int,
  value_id : Int,
  instr_for_memarg : (@lib.MemArg) -> @lib.Instruction,
) -> Unit {
  let memarg = optimize_instructions_memarg_for_mem_idx(mem_idx)
  let temp = @ir.hot_build_store(func, memarg, address_id, value_id)
  @ir.hot_node_exact_instr_set(func, temp, instr_for_memarg(memarg))
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_repeated_fill_i32(raw : Int, size : Int) -> @lib.I32? {
  let byte = raw.reinterpret_as_uint() & 0xff
  match size {
    1 => Some(@lib.I32(byte.reinterpret_as_int()))
    2 => Some(@lib.I32((byte | (byte << 8)).reinterpret_as_int()))
    4 =>
      Some(
        @lib.I32(
          (byte | (byte << 8) | (byte << 16) | (byte << 24)).reinterpret_as_int(),
        ),
      )
    _ => None
  }
}

///|
fn optimize_instructions_repeated_fill_i64(raw : Int) -> @lib.I64 {
  let byte = (raw.reinterpret_as_uint() & 0xff).to_uint64()
  @lib.I64(
    (byte |
    (byte << 8) |
    (byte << 16) |
    (byte << 24) |
    (byte << 32) |
    (byte << 40) |
    (byte << 48) |
    (byte << 56)).reinterpret_as_int64(),
  )
}

///|
fn optimize_instructions_build_repeated_fill_v128_const(
  func : @ir.HotFunc,
  raw : Int,
) -> Int {
  let byte = (raw.reinterpret_as_uint() & 0xff).to_byte()
  @ir.hot_build_const_v128_splat(func, byte)
}

///|
priv enum OiTinyMemoryFillStoreFact {
  Store8
  Store16
  Store32
  Store64
  StoreV128
}

///|
priv enum OiTinyMemoryFillValueFact {
  RepeatedByte(Int)
  OriginalI32Value
}

///|
priv struct OiTinyMemoryFillFact {
  size : Int
  store_fact : OiTinyMemoryFillStoreFact
  value_fact : OiTinyMemoryFillValueFact
}

///|
fn OiTinyMemoryFillStoreFact::from_size(
  size : Int,
) -> OiTinyMemoryFillStoreFact? {
  match size {
    1 => Some(Store8)
    2 => Some(Store16)
    4 => Some(Store32)
    8 => Some(Store64)
    16 => Some(StoreV128)
    _ => None
  }
}

///|
fn OiTinyMemoryFillStoreFact::instruction(
  self : OiTinyMemoryFillStoreFact,
  memarg : @lib.MemArg,
) -> @lib.Instruction {
  match self {
    Store8 => @lib.Instruction::i32_store8(memarg)
    Store16 => @lib.Instruction::i32_store16(memarg)
    Store32 => @lib.Instruction::i32_store(memarg)
    Store64 => @lib.Instruction::i64_store(memarg)
    StoreV128 => @lib.Instruction::v128_store(memarg)
  }
}

///|
fn OiTinyMemoryFillFact::from_repeated_byte(
  ctx : HotPassContext,
  size : Int,
  byte : Int,
) -> OiTinyMemoryFillFact? {
  let store_fact = match OiTinyMemoryFillStoreFact::from_size(size) {
    Some(fact) => fact
    None => return None
  }
  // Binaryen v130 `optimizeMemoryFill` always lowers constant sizes 1/2, only
  // lowers constant sizes 4/8 for zero bytes or `shrinkLevel == 0`, and only
  // lowers constant size 16 at `shrinkLevel == 0` (with a SIMD store when the
  // module feature set permits it; Starshine currently has no module feature
  // fact, so the no-SIMD two-i64-store fallback stays documented as open).
  let may_lower = match size {
    1 | 2 => true
    4 | 8 => byte == 0 || ctx.shrink_level == 0
    16 => ctx.shrink_level == 0
    _ => false
  }
  if may_lower {
    Some({ size, store_fact, value_fact: RepeatedByte(byte) })
  } else {
    None
  }
}

///|
fn OiTinyMemoryFillFact::from_size_and_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  size : Int,
  value_id : Int,
) -> OiTinyMemoryFillFact? {
  match optimize_instructions_i32_const_for_memory_fill(func, dead, value_id) {
    Some(@lib.I32(raw)) => {
      let byte = (raw.reinterpret_as_uint() & 0xff).reinterpret_as_int()
      OiTinyMemoryFillFact::from_repeated_byte(ctx, size, byte)
    }
    None =>
      if size == 1 {
        Some({ size, store_fact: Store8, value_fact: OriginalI32Value })
      } else {
        None
      }
  }
}

///|
fn OiTinyMemoryFillFact::store_instr(
  self : OiTinyMemoryFillFact,
  memarg : @lib.MemArg,
) -> @lib.Instruction {
  self.store_fact.instruction(memarg)
}

///|
fn OiTinyMemoryFillFact::build_store_value(
  self : OiTinyMemoryFillFact,
  func : @ir.HotFunc,
  original_value_id : Int,
) -> Int? {
  match self.value_fact {
    RepeatedByte(raw) =>
      match self.store_fact {
        Store8 | Store16 | Store32 =>
          match optimize_instructions_repeated_fill_i32(raw, self.size) {
            Some(value) => Some(@ir.hot_build_const_i32(func, value))
            None => None
          }
        Store64 =>
          Some(
            @ir.hot_build_const_i64(
              func,
              optimize_instructions_repeated_fill_i64(raw),
            ),
          )
        StoreV128 =>
          Some(optimize_instructions_build_repeated_fill_v128_const(func, raw))
      }
    OriginalI32Value =>
      if self.size == 1 {
        Some(original_value_id)
      } else {
        None
      }
  }
}

///|
fn optimize_instructions_build_i32_binary(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Int {
  let node_id = @ir.hot_build_binary(func, @lib.ValType::i32(), lhs_id, rhs_id)
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  node_id
}

///|
priv struct OiMemoryAccessFact {
  instr : @lib.Instruction
  load_result_type : @lib.ValType?
  store_value_bits : Int?
  store_value_is_i64 : Bool
}

///|
fn OiMemoryAccessFact::from_instr(
  instr : @lib.Instruction,
) -> OiMemoryAccessFact? {
  let load_result_type = match instr {
    @lib.Instruction::I32Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_) => Some(@lib.ValType::i32())
    @lib.Instruction::I64Load(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_) => Some(@lib.ValType::i64())
    @lib.Instruction::F32Load(_) => Some(@lib.ValType::f32())
    @lib.Instruction::F64Load(_) => Some(@lib.ValType::f64())
    _ => None
  }
  let store_value_bits = match instr {
    @lib.Instruction::I32Store8(_) | @lib.Instruction::I64Store8(_) => Some(8)
    @lib.Instruction::I32Store16(_) | @lib.Instruction::I64Store16(_) =>
      Some(16)
    @lib.Instruction::I64Store32(_) => Some(32)
    _ => None
  }
  let store_value_is_i64 = match instr {
    @lib.Instruction::I64Store8(_)
    | @lib.Instruction::I64Store16(_)
    | @lib.Instruction::I64Store32(_) => true
    _ => false
  }
  match instr {
    @lib.Instruction::I32Load(_)
    | @lib.Instruction::I64Load(_)
    | @lib.Instruction::F32Load(_)
    | @lib.Instruction::F64Load(_)
    | @lib.Instruction::I32Load8S(_)
    | @lib.Instruction::I32Load8U(_)
    | @lib.Instruction::I32Load16S(_)
    | @lib.Instruction::I32Load16U(_)
    | @lib.Instruction::I64Load8S(_)
    | @lib.Instruction::I64Load8U(_)
    | @lib.Instruction::I64Load16S(_)
    | @lib.Instruction::I64Load16U(_)
    | @lib.Instruction::I64Load32S(_)
    | @lib.Instruction::I64Load32U(_)
    | @lib.Instruction::I32Store(_)
    | @lib.Instruction::I64Store(_)
    | @lib.Instruction::F32Store(_)
    | @lib.Instruction::F64Store(_)
    | @lib.Instruction::I32Store8(_)
    | @lib.Instruction::I32Store16(_)
    | @lib.Instruction::I64Store8(_)
    | @lib.Instruction::I64Store16(_)
    | @lib.Instruction::I64Store32(_) =>
      Some({ instr, load_result_type, store_value_bits, store_value_is_i64 })
    _ => None
  }
}

///|
fn OiMemoryAccessFact::with_memarg(
  self : OiMemoryAccessFact,
  memarg : @lib.MemArg,
) -> @lib.Instruction? {
  match self.instr {
    @lib.Instruction::I32Load(_) => Some(@lib.Instruction::i32_load(memarg))
    @lib.Instruction::I64Load(_) => Some(@lib.Instruction::i64_load(memarg))
    @lib.Instruction::F32Load(_) => Some(@lib.Instruction::f32_load(memarg))
    @lib.Instruction::F64Load(_) => Some(@lib.Instruction::f64_load(memarg))
    @lib.Instruction::I32Load8S(_) => Some(@lib.Instruction::i32_load8s(memarg))
    @lib.Instruction::I32Load8U(_) => Some(@lib.Instruction::i32_load8u(memarg))
    @lib.Instruction::I32Load16S(_) =>
      Some(@lib.Instruction::i32_load16s(memarg))
    @lib.Instruction::I32Load16U(_) =>
      Some(@lib.Instruction::i32_load16u(memarg))
    @lib.Instruction::I64Load8S(_) => Some(@lib.Instruction::i64_load8s(memarg))
    @lib.Instruction::I64Load8U(_) => Some(@lib.Instruction::i64_load8u(memarg))
    @lib.Instruction::I64Load16S(_) =>
      Some(@lib.Instruction::i64_load16s(memarg))
    @lib.Instruction::I64Load16U(_) =>
      Some(@lib.Instruction::i64_load16u(memarg))
    @lib.Instruction::I64Load32S(_) =>
      Some(@lib.Instruction::i64_load32s(memarg))
    @lib.Instruction::I64Load32U(_) =>
      Some(@lib.Instruction::i64_load32u(memarg))
    @lib.Instruction::I32Store(_) => Some(@lib.Instruction::i32_store(memarg))
    @lib.Instruction::I64Store(_) => Some(@lib.Instruction::i64_store(memarg))
    @lib.Instruction::F32Store(_) => Some(@lib.Instruction::f32_store(memarg))
    @lib.Instruction::F64Store(_) => Some(@lib.Instruction::f64_store(memarg))
    @lib.Instruction::I32Store8(_) => Some(@lib.Instruction::i32_store8(memarg))
    @lib.Instruction::I32Store16(_) =>
      Some(@lib.Instruction::i32_store16(memarg))
    @lib.Instruction::I64Store8(_) => Some(@lib.Instruction::i64_store8(memarg))
    @lib.Instruction::I64Store16(_) =>
      Some(@lib.Instruction::i64_store16(memarg))
    @lib.Instruction::I64Store32(_) =>
      Some(@lib.Instruction::i64_store32(memarg))
    _ => None
  }
}

///|
priv struct OiStoredValueFact {
  instr : @lib.Instruction
  address_id : Int
  value_id : Int
  access_fact : OiMemoryAccessFact
}

///|
fn OiStoredValueFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiStoredValueFact? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Store => ()
    _ => return None
  }
  if node.child_count != 2 {
    return None
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return None
  }
  let access_fact = match OiMemoryAccessFact::from_instr(instr) {
    Some(fact) => fact
    None => return None
  }
  Some({
    instr,
    address_id: @ir.hot_child_get(func, node_id, 0),
    value_id: @ir.hot_child_get(func, node_id, 1),
    access_fact,
  })
}

///|
fn OiStoredValueFact::build_truncated_const_value(
  self : OiStoredValueFact,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> Int? {
  let bits = match self.access_fact.store_value_bits {
    Some(bits) => bits
    None => return None
  }
  if self.access_fact.store_value_is_i64 {
    let raw = match optimize_instructions_i64_const(func, dead, self.value_id) {
      Some(@lib.I64(raw)) => raw
      _ => return None
    }
    let mask = (1L << bits) - 1L
    let truncated = raw & mask
    if truncated == raw {
      return None
    }
    Some(@ir.hot_build_const_i64(func, @lib.I64(truncated)))
  } else {
    let raw = match optimize_instructions_i32_const(func, dead, self.value_id) {
      Some(@lib.I32(raw)) => raw
      _ => return None
    }
    let mask = (1 << bits) - 1
    let truncated = raw & mask
    if truncated == raw {
      return None
    }
    Some(@ir.hot_build_const_i32(func, @lib.I32(truncated)))
  }
}

///|
fn OiStoredValueFact::low_bit_mask_unmasked_value(
  self : OiStoredValueFact,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> Int? {
  let bits = match self.access_fact.store_value_bits {
    Some(bits) => bits
    None => return None
  }
  // Binaryen version_130 `optimizeStoredValue` only drops exact i32 low-bit
  // masks before i32 narrow stores. It preserves superset masks and all i64
  // masks before i64 narrow stores, even though those masks are semantically
  // redundant for the store.
  if self.access_fact.store_value_is_i64 {
    return None
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, self.value_id) {
    return None
  }
  let value = @ir.hot_node_get(func, self.value_id)
  match value.op {
    @ir.HotOp::Binary => ()
    _ => return None
  }
  if value.child_count != 2 {
    return None
  }
  if @ir.hot_node_exact_instr(func, self.value_id) !=
    Some(@lib.Instruction::i32_and()) {
    return None
  }
  let lhs_id = @ir.hot_child_get(func, self.value_id, 0)
  let rhs_id = @ir.hot_child_get(func, self.value_id, 1)
  let (mask, unmasked_id) = match
    optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => (raw, lhs_id)
    _ =>
      match optimize_instructions_i32_const(func, dead, lhs_id) {
        Some(@lib.I32(raw)) => (raw, rhs_id)
        _ => return None
      }
  }
  let required_mask = (1 << bits) - 1
  if mask == required_mask {
    Some(unmasked_id)
  } else {
    None
  }
}

///|
fn OiStoredValueFact::reinterpret_rewrite(
  self : OiStoredValueFact,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> (@lib.Instruction, Int)? {
  if !OiLiveNodeFact::proves_node_live(func, dead, self.value_id) {
    return None
  }
  let value = @ir.hot_node_get(func, self.value_id)
  if value.child_count != 1 {
    return None
  }
  let new_instr = match
    (self.instr, @ir.hot_node_exact_instr(func, self.value_id)) {
    (
      @lib.Instruction::F32Store(memarg),
      Some(@lib.Instruction::F32ReinterpretI32),
    ) => @lib.Instruction::i32_store(memarg)
    (
      @lib.Instruction::F64Store(memarg),
      Some(@lib.Instruction::F64ReinterpretI64),
    ) => @lib.Instruction::i64_store(memarg)
    (
      @lib.Instruction::I32Store(memarg),
      Some(@lib.Instruction::I32ReinterpretF32),
    ) => @lib.Instruction::f32_store(memarg)
    (
      @lib.Instruction::I64Store(memarg),
      Some(@lib.Instruction::I64ReinterpretF64),
    ) => @lib.Instruction::f64_store(memarg)
    _ => return None
  }
  Some((new_instr, @ir.hot_child_get(func, self.value_id, 0)))
}

///|
fn OiStoredValueFact::wrap_i64_widen_rewrite(
  self : OiStoredValueFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> (@lib.Instruction, Int)? {
  // Storing the low N bits of (i32.wrap_i64 x) is equivalent to storing the low
  // N bits of x directly via the matching i64 narrow store, so a direct one-use
  // wrap value child can be dropped by widening the store.
  let new_instr = match self.instr {
    @lib.Instruction::I32Store8(ma) => @lib.Instruction::i64_store8(ma)
    @lib.Instruction::I32Store16(ma) => @lib.Instruction::i64_store16(ma)
    @lib.Instruction::I32Store(ma) => @lib.Instruction::i64_store32(ma)
    _ => return None
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, self.value_id) {
    return None
  }
  match @ir.hot_node_exact_instr(func, self.value_id) {
    Some(@lib.Instruction::I32WrapI64) => ()
    _ => return None
  }
  let value = @ir.hot_node_get(func, self.value_id)
  if value.child_count != 1 {
    return None
  }
  // Only drop the wrap when this store is its sole use, so the wrap node can be
  // cleaned up instead of leaving a dangling i32 producer.
  if pass_node_use_count(ctx, func, self.value_id) != 1 {
    return None
  }
  Some((new_instr, @ir.hot_child_get(func, self.value_id, 0)))
}

///|
priv enum OiStoredValueRewritePlanKind {
  StoredValueTruncateConst
  StoredValueDropLowBitMask
  StoredValueRewriteReinterpret
  StoredValueWidenWrapI64
}

///|
priv struct OiStoredValueRewritePlanFact {
  kind : OiStoredValueRewritePlanKind
  stored_fact : OiStoredValueFact
  new_instr : @lib.Instruction
  new_value_id : Int
}

///|
fn OiStoredValueRewritePlanFact::from_truncated_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiStoredValueRewritePlanFact? {
  // Binaryen v130 `optimizeStoredValue` rewrites narrow-store constants by
  // deriving the preserved low bits from the store access fact. Keep the final
  // replacement as a plan fact so the visitor does not own a separate store
  // scanner for each OI-G stored-value family.
  let stored_fact = match OiStoredValueFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let new_value_id = match stored_fact.build_truncated_const_value(func, dead) {
    Some(value_id) => value_id
    None => return None
  }
  Some({
    kind: StoredValueTruncateConst,
    stored_fact,
    new_instr: stored_fact.instr,
    new_value_id,
  })
}

///|
fn OiStoredValueRewritePlanFact::from_low_bit_mask(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiStoredValueRewritePlanFact? {
  let stored_fact = match OiStoredValueFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let new_value_id = match stored_fact.low_bit_mask_unmasked_value(func, dead) {
    Some(value_id) => value_id
    None => return None
  }
  Some({
    kind: StoredValueDropLowBitMask,
    stored_fact,
    new_instr: stored_fact.instr,
    new_value_id,
  })
}

///|
fn OiStoredValueRewritePlanFact::from_reinterpret(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiStoredValueRewritePlanFact? {
  let stored_fact = match OiStoredValueFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let (new_instr, new_value_id) = match
    stored_fact.reinterpret_rewrite(func, dead) {
    Some(rewrite) => rewrite
    None => return None
  }
  Some({
    kind: StoredValueRewriteReinterpret,
    stored_fact,
    new_instr,
    new_value_id,
  })
}

///|
fn OiStoredValueRewritePlanFact::from_wrap_i64_widen(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiStoredValueRewritePlanFact? {
  let stored_fact = match OiStoredValueFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let (new_instr, new_value_id) = match
    stored_fact.wrap_i64_widen_rewrite(ctx, func, dead) {
    Some(rewrite) => rewrite
    None => return None
  }
  Some({ kind: StoredValueWidenWrapI64, stored_fact, new_instr, new_value_id })
}

///|
fn OiStoredValueRewritePlanFact::apply(
  self : OiStoredValueRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    StoredValueTruncateConst
    | StoredValueDropLowBitMask
    | StoredValueRewriteReinterpret
    | StoredValueWidenWrapI64 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        self.new_instr,
        [self.stored_fact.address_id, self.new_value_id],
      )
      true
    }
  }
}

///|
priv struct OiLoadResultFact {
  consumer_instr : @lib.Instruction
  load_instr : @lib.Instruction
  address_id : Int
}

///|
fn OiLoadResultFact::from_unary_consumer(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiLoadResultFact? {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return None
  }
  let load_id = @ir.hot_child_get(func, node_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, load_id) ||
    pass_node_use_count(ctx, func, load_id) != 1 {
    return None
  }
  let load = @ir.hot_node_get(func, load_id)
  match load.op {
    @ir.HotOp::Load => ()
    _ => return None
  }
  if load.child_count != 1 {
    return None
  }
  let consumer_instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return None
  }
  let load_instr = match @ir.hot_node_exact_instr(func, load_id) {
    Some(instr) => instr
    None => return None
  }
  Some({
    consumer_instr,
    load_instr,
    address_id: @ir.hot_child_get(func, load_id, 0),
  })
}

///|
fn OiLoadResultFact::reinterpret_load_instr(
  self : OiLoadResultFact,
) -> @lib.Instruction? {
  // Binaryen v130 `visitUnary` rewrites one-use non-atomic representation loads
  // through reinterpret consumers by mutating the load type in place.
  match (self.load_instr, self.consumer_instr) {
    (@lib.Instruction::I32Load(memarg), @lib.Instruction::F32ReinterpretI32) =>
      Some(@lib.Instruction::f32_load(memarg))
    (@lib.Instruction::I64Load(memarg), @lib.Instruction::F64ReinterpretI64) =>
      Some(@lib.Instruction::f64_load(memarg))
    (@lib.Instruction::F32Load(memarg), @lib.Instruction::I32ReinterpretF32) =>
      Some(@lib.Instruction::i32_load(memarg))
    (@lib.Instruction::F64Load(memarg), @lib.Instruction::I64ReinterpretF64) =>
      Some(@lib.Instruction::i64_load(memarg))
    _ => None
  }
}

///|
fn OiLoadResultFact::i64_extend_i32_load_instr(
  self : OiLoadResultFact,
) -> @lib.Instruction? {
  // Binaryen v130 rewrites one-use i32 loads under i64.extend_i32 when the
  // signedness/atomic constraints are represented by an equivalent i64 load.
  match (self.load_instr, self.consumer_instr) {
    (@lib.Instruction::I32Load(memarg), @lib.Instruction::I64ExtendI32U) =>
      Some(@lib.Instruction::i64_load32u(memarg))
    (@lib.Instruction::I32Load(memarg), @lib.Instruction::I64ExtendI32S) =>
      Some(@lib.Instruction::i64_load32s(memarg))
    (
      @lib.Instruction::I32Load8U(memarg),
      @lib.Instruction::I64ExtendI32U
      | @lib.Instruction::I64ExtendI32S,
    ) => Some(@lib.Instruction::i64_load8u(memarg))
    (
      @lib.Instruction::I32Load16U(memarg),
      @lib.Instruction::I64ExtendI32U
      | @lib.Instruction::I64ExtendI32S,
    ) => Some(@lib.Instruction::i64_load16u(memarg))
    (@lib.Instruction::I32Load8S(memarg), @lib.Instruction::I64ExtendI32S) =>
      Some(@lib.Instruction::i64_load8s(memarg))
    (@lib.Instruction::I32Load16S(memarg), @lib.Instruction::I64ExtendI32S) =>
      Some(@lib.Instruction::i64_load16s(memarg))
    _ => None
  }
}

///|
priv enum OiLoadResultRewritePlanKind {
  LoadResultRewriteReinterpret
  LoadResultRewriteI64ExtendI32
}

///|
priv struct OiLoadResultRewritePlanFact {
  kind : OiLoadResultRewritePlanKind
  load_fact : OiLoadResultFact
  new_instr : @lib.Instruction
}

///|
fn OiLoadResultRewritePlanFact::from_reinterpret(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiLoadResultRewritePlanFact? {
  // Binaryen v130 `visitUnary` mutates one-use representation loads underneath
  // reinterpret consumers. Keep the mutation target as a plan fact beside the
  // load-result fact instead of repeating the unary/load scanner in each
  // visitor rewrite branch.
  let load_fact = match
    OiLoadResultFact::from_unary_consumer(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return None
  }
  let new_instr = match load_fact.reinterpret_load_instr() {
    Some(instr) => instr
    None => return None
  }
  Some({ kind: LoadResultRewriteReinterpret, load_fact, new_instr })
}

///|
fn OiLoadResultRewritePlanFact::from_i64_extend_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiLoadResultRewritePlanFact? {
  let load_fact = match
    OiLoadResultFact::from_unary_consumer(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return None
  }
  let new_instr = match load_fact.i64_extend_i32_load_instr() {
    Some(instr) => instr
    None => return None
  }
  Some({ kind: LoadResultRewriteI64ExtendI32, load_fact, new_instr })
}

///|
fn OiLoadResultRewritePlanFact::apply(
  self : OiLoadResultRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    LoadResultRewriteReinterpret | LoadResultRewriteI64ExtendI32 => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        self.new_instr,
        [self.load_fact.address_id],
      )
      true
    }
  }
}

///|
priv struct OiAtomicAccessFact {
  instr : @lib.Instruction
}

///|
fn OiAtomicAccessFact::from_instr(
  instr : @lib.Instruction,
) -> OiAtomicAccessFact? {
  match instr {
    @lib.Instruction::I32AtomicLoad(_)
    | @lib.Instruction::I64AtomicLoad(_)
    | @lib.Instruction::I32AtomicLoad8U(_)
    | @lib.Instruction::I32AtomicLoad16U(_)
    | @lib.Instruction::I64AtomicLoad8U(_)
    | @lib.Instruction::I64AtomicLoad16U(_)
    | @lib.Instruction::I64AtomicLoad32U(_)
    | @lib.Instruction::I32AtomicStore(_)
    | @lib.Instruction::I64AtomicStore(_)
    | @lib.Instruction::I32AtomicStore8(_)
    | @lib.Instruction::I32AtomicStore16(_)
    | @lib.Instruction::I64AtomicStore8(_)
    | @lib.Instruction::I64AtomicStore16(_)
    | @lib.Instruction::I64AtomicStore32(_) => Some({ instr, })
    _ => None
  }
}

///|
fn OiAtomicAccessFact::with_memarg(
  self : OiAtomicAccessFact,
  memarg : @lib.MemArg,
) -> @lib.Instruction? {
  match self.instr {
    @lib.Instruction::I32AtomicLoad(_) =>
      Some(@lib.Instruction::i32_atomic_load(memarg))
    @lib.Instruction::I64AtomicLoad(_) =>
      Some(@lib.Instruction::i64_atomic_load(memarg))
    @lib.Instruction::I32AtomicLoad8U(_) =>
      Some(@lib.Instruction::i32_atomic_load8_u(memarg))
    @lib.Instruction::I32AtomicLoad16U(_) =>
      Some(@lib.Instruction::i32_atomic_load16_u(memarg))
    @lib.Instruction::I64AtomicLoad8U(_) =>
      Some(@lib.Instruction::i64_atomic_load8_u(memarg))
    @lib.Instruction::I64AtomicLoad16U(_) =>
      Some(@lib.Instruction::i64_atomic_load16_u(memarg))
    @lib.Instruction::I64AtomicLoad32U(_) =>
      Some(@lib.Instruction::i64_atomic_load32_u(memarg))
    @lib.Instruction::I32AtomicStore(_) =>
      Some(@lib.Instruction::i32_atomic_store(memarg))
    @lib.Instruction::I64AtomicStore(_) =>
      Some(@lib.Instruction::i64_atomic_store(memarg))
    @lib.Instruction::I32AtomicStore8(_) =>
      Some(@lib.Instruction::i32_atomic_store8(memarg))
    @lib.Instruction::I32AtomicStore16(_) =>
      Some(@lib.Instruction::i32_atomic_store16(memarg))
    @lib.Instruction::I64AtomicStore8(_) =>
      Some(@lib.Instruction::i64_atomic_store8(memarg))
    @lib.Instruction::I64AtomicStore16(_) =>
      Some(@lib.Instruction::i64_atomic_store16(memarg))
    @lib.Instruction::I64AtomicStore32(_) =>
      Some(@lib.Instruction::i64_atomic_store32(memarg))
    _ => None
  }
}

///|
// Binaryen v130 `optimizeMemoryAccess` folds a constant address plus a static
// memory offset into a zero-offset access under memory32/memory64 overflow
// guards. Keep that proof in one OI-G fact instead of open-coding the
// load/store/atomic scanner at each rewrite site.
priv struct OiMemoryOffsetFoldFact {
  instr : @lib.Instruction
  address_id : Int
  new_memarg : @lib.MemArg
  folded_i32_address : @lib.I32?
  folded_i64_address : @lib.I64?
}

///|
fn OiMemoryOffsetFoldFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiMemoryOffsetFoldFact? {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count == 0 {
    return None
  }
  match node.op {
    @ir.HotOp::Load | @ir.HotOp::Store | @ir.HotOp::Atomic => ()
    _ => return None
  }
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return None
  }
  match instr {
    @lib.Instruction::StructAtomicGet(_, _, _)
    | @lib.Instruction::StructAtomicGetS(_, _, _)
    | @lib.Instruction::StructAtomicGetU(_, _, _)
    | @lib.Instruction::StructAtomicRmw(_, _, _)
    | @lib.Instruction::StructAtomicCmpxchg(_, _)
    | @lib.Instruction::ArrayAtomicRmw(_, _)
    | @lib.Instruction::ArrayAtomicCmpxchg(_) => return None
    _ => ()
  }
  let @lib.MemArg(align, mem, @lib.U64(offset)) = @ir.hot_memarg_get(
      func,
      node.imm0,
    ).memarg
  if offset == 0UL {
    return None
  }
  let address_id = @ir.hot_child_get(func, node_id, 0)
  let address = @ir.hot_node_get(func, address_id)
  match address.op {
    @ir.HotOp::Const => ()
    _ => return None
  }
  let (folded_i32_address, folded_i64_address) = match
    @ir.hot_const_get(func, address.imm0) {
    @ir.HotConstPayload::I32Const(@lib.I32(raw)) => {
      if raw < 0 {
        return None
      }
      let raw_u = raw.reinterpret_as_uint()
      if raw_u > 2147483647U {
        return None
      }
      let sum = raw_u.to_uint64() + offset
      if sum > 2147483647UL {
        return None
      }
      (Some(@lib.I32(sum.to_uint().reinterpret_as_int())), None)
    }
    @ir.HotConstPayload::I64Const(@lib.I64(raw)) => {
      let raw_u = raw.reinterpret_as_uint64()
      if raw_u > 18446744073709551615UL - offset {
        return None
      }
      let sum = raw_u + offset
      (None, Some(@lib.I64(sum.reinterpret_as_int64())))
    }
    _ => return None
  }
  Some({
    instr,
    address_id,
    new_memarg: @lib.MemArg::new(align, mem, @lib.U64(0UL)),
    folded_i32_address,
    folded_i64_address,
  })
}

///|
fn OiMemoryOffsetFoldFact::build_address_const(
  self : OiMemoryOffsetFoldFact,
  func : @ir.HotFunc,
) -> Int? {
  ignore(self.address_id)
  match (self.folded_i32_address, self.folded_i64_address) {
    (Some(value), None) => Some(@ir.hot_build_const_i32(func, value))
    (None, Some(value)) => Some(@ir.hot_build_const_i64(func, value))
    _ => None
  }
}

///|
fn OiMemoryOffsetFoldFact::access_fact(
  self : OiMemoryOffsetFoldFact,
) -> OiMemoryAccessFact? {
  OiMemoryAccessFact::from_instr(self.instr)
}

///|
fn OiMemoryOffsetFoldFact::atomic_fact(
  self : OiMemoryOffsetFoldFact,
) -> OiAtomicAccessFact? {
  OiAtomicAccessFact::from_instr(self.instr)
}

///|
priv enum OiMemoryOffsetFoldRewritePlanKind {
  MemoryOffsetFoldLoad
  MemoryOffsetFoldStore
  MemoryOffsetFoldAtomic
}

///|
priv struct OiMemoryOffsetFoldRewritePlanFact {
  kind : OiMemoryOffsetFoldRewritePlanKind
  offset_fact : OiMemoryOffsetFoldFact
  new_address_id : Int
  new_instr : @lib.Instruction
  store_value_id : Int
  load_result_type : @lib.ValType?
}

///|
fn OiMemoryOffsetFoldRewritePlanFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiMemoryOffsetFoldRewritePlanFact? {
  // Binaryen v130 `optimizeMemoryAccess` derives one source-level address
  // folding fact, then rebuilds the matching load/store/atomic access with the
  // zero-offset memarg. Keep the replacement choice here so the visitor does
  // not own a separate memory-access scanner after `OiMemoryOffsetFoldFact` has
  // proven the overflow-safe constant fold.
  let node = @ir.hot_node_get(func, node_id)
  let offset_fact = match OiMemoryOffsetFoldFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return None
  }
  let new_address_id = match offset_fact.build_address_const(func) {
    Some(address_id) => address_id
    None => return None
  }
  match node.op {
    @ir.HotOp::Atomic => {
      if node.child_count != 1 && node.child_count != 2 {
        return None
      }
      let atomic_fact = match offset_fact.atomic_fact() {
        Some(fact) => fact
        None => return None
      }
      let new_instr = match atomic_fact.with_memarg(offset_fact.new_memarg) {
        Some(instr) => instr
        None => return None
      }
      Some({
        kind: MemoryOffsetFoldAtomic,
        offset_fact,
        new_address_id,
        new_instr,
        store_value_id: -1,
        load_result_type: None,
      })
    }
    @ir.HotOp::Load => {
      if node.child_count != 1 {
        return None
      }
      let access_fact = match offset_fact.access_fact() {
        Some(fact) => fact
        None => return None
      }
      let result_type = match access_fact.load_result_type {
        Some(result_type) => result_type
        None => return None
      }
      let new_instr = match access_fact.with_memarg(offset_fact.new_memarg) {
        Some(instr) => instr
        None => return None
      }
      Some({
        kind: MemoryOffsetFoldLoad,
        offset_fact,
        new_address_id,
        new_instr,
        store_value_id: -1,
        load_result_type: Some(result_type),
      })
    }
    @ir.HotOp::Store => {
      if node.child_count != 2 {
        return None
      }
      let access_fact = match offset_fact.access_fact() {
        Some(fact) => fact
        None => return None
      }
      let new_instr = match access_fact.with_memarg(offset_fact.new_memarg) {
        Some(instr) => instr
        None => return None
      }
      Some({
        kind: MemoryOffsetFoldStore,
        offset_fact,
        new_address_id,
        new_instr,
        store_value_id: @ir.hot_child_get(func, node_id, 1),
        load_result_type: None,
      })
    }
    _ => None
  }
}

///|
fn OiMemoryOffsetFoldRewritePlanFact::apply(
  self : OiMemoryOffsetFoldRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    MemoryOffsetFoldAtomic => {
      @ir.hot_child_set(func, node_id, 0, self.new_address_id)
      @ir.hot_node_exact_instr_set(func, node_id, self.new_instr)
      pass_mark_mutated(ctx, func)
      true
    }
    MemoryOffsetFoldLoad => {
      let result_type = match self.load_result_type {
        Some(result_type) => result_type
        None => return false
      }
      let temp = @ir.hot_build_load(
        func,
        result_type,
        self.offset_fact.new_memarg,
        self.new_address_id,
      )
      @ir.hot_node_exact_instr_set(func, temp, self.new_instr)
      let replacement = @ir.hot_node_get(func, temp)
      @ir.hot_delete_node(func, temp)
      @ir.hot_replace_node(func, node_id, replacement)
      pass_mark_mutated(ctx, func)
      true
    }
    MemoryOffsetFoldStore => {
      let temp = @ir.hot_build_store(
        func,
        self.offset_fact.new_memarg,
        self.new_address_id,
        self.store_value_id,
      )
      @ir.hot_node_exact_instr_set(func, temp, self.new_instr)
      let replacement = @ir.hot_node_get(func, temp)
      @ir.hot_delete_node(func, temp)
      @ir.hot_replace_node(func, node_id, replacement)
      pass_mark_mutated(ctx, func)
      true
    }
  }
}

///|
fn optimize_instructions_struct_atomic_field_type(
  ctx : HotPassContext,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
) -> @lib.ValType? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let @lib.U32(raw_field) = field_idx
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  let field = match fields.get(raw_field.reinterpret_as_int()) {
    Some(field) => field
    None => return None
  }
  if !field.is_mutable() || field.get_storage_type().is_packed() {
    return None
  }
  let value_type = field.unpack()
  if value_type == @lib.ValType::i32() || value_type == @lib.ValType::i64() {
    Some(value_type)
  } else {
    None
  }
}

///|
fn optimize_instructions_add_temp_local(
  func : @ir.HotFunc,
  value_type : @lib.ValType,
) -> Int {
  let local_id = @ir.hot_local_count(func)
  func.locals.locals.push(value_type)
  local_id
}

///|
fn optimize_instructions_build_exact_heap(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  result_type : @lib.ValType?,
  children : Array[Int],
) -> Int {
  let result_types = match result_type {
    Some(value_type) => [value_type]
    None => []
  }
  @ir.hot_build_heap(func, result_types, instr, children)
}

///|
fn optimize_instructions_build_exact_atomic(
  func : @ir.HotFunc,
  instr : @lib.Instruction,
  result_type : @lib.ValType?,
  children : Array[Int],
) -> Int {
  let result_types = match result_type {
    Some(value_type) => [value_type]
    None => []
  }
  @ir.hot_build_atomic(func, result_types, instr, children)
}

///|
fn optimize_instructions_build_exact_binary_for_value_type(
  func : @ir.HotFunc,
  value_type : @lib.ValType,
  instr32 : @lib.Instruction,
  instr64 : @lib.Instruction,
  lhs : Int,
  rhs : Int,
) -> Int? {
  let instr = if value_type == @lib.ValType::i32() {
    instr32
  } else if value_type == @lib.ValType::i64() {
    instr64
  } else {
    return None
  }
  let node_id = @ir.hot_build_binary(func, value_type, lhs, rhs)
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  Some(node_id)
}

///|
fn optimize_instructions_build_exact_compare_for_value_type(
  func : @ir.HotFunc,
  value_type : @lib.ValType,
  instr32 : @lib.Instruction,
  instr64 : @lib.Instruction,
  lhs : Int,
  rhs : Int,
) -> Int? {
  let instr = if value_type == @lib.ValType::i32() {
    instr32
  } else if value_type == @lib.ValType::i64() {
    instr64
  } else {
    return None
  }
  let node_id = @ir.hot_build_compare(func, lhs, rhs)
  @ir.hot_node_exact_instr_set(func, node_id, instr)
  Some(node_id)
}

///|
fn optimize_instructions_replace_with_value_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  result_type : @lib.ValType,
  body : Array[Int],
) -> Unit {
  @ir.hot_node_promote_to_block(
    func,
    node_id,
    @lib.BlockType::val_type(result_type),
    body,
  )
  for root_idx = 0
      root_idx + 1 < @ir.hot_root_count(func)
      root_idx = root_idx + 1 {
    if @ir.hot_root_get(func, root_idx) == node_id {
      let next_root = @ir.hot_root_get(func, root_idx + 1)
      match @ir.hot_node_get(func, next_root).op {
        @ir.HotOp::Unreachable => {
          ignore(@ir.hot_root_remove(func, root_idx + 1))
          break
        }
        _ => ()
      }
    }
  }
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_i32_const_is(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  value : Int,
) -> Bool {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(raw)) => raw == value
    _ => false
  }
}

///|
fn optimize_instructions_i64_const_is(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  value : Int64,
) -> Bool {
  match optimize_instructions_i64_const(func, dead, node_id) {
    Some(@lib.I64(raw)) => raw == value
    _ => false
  }
}

///|
priv struct OiStructAtomicFieldFact {
  type_idx : @lib.TypeIdx
  field_idx : @lib.U32
  value_type : @lib.ValType
}

///|
fn OiStructAtomicFieldFact::from_index(
  ctx : HotPassContext,
  type_idx : @lib.TypeIdx,
  field_idx : @lib.U32,
) -> OiStructAtomicFieldFact? {
  // Binaryen v130 `visitStructRMW` / `visitStructCmpxchg` only continue when
  // the receiver is a struct and the aggregate atomic produces a concrete field
  // value. Starshine's HOT fact is intentionally narrower: it accepts resolved,
  // mutable, unpacked i32/i64 struct fields, matching the represented OI-L
  // lowering surface and leaving packed/ref fields to documented reopeners.
  match
    optimize_instructions_struct_atomic_field_type(ctx, type_idx, field_idx) {
    Some(value_type) => Some({ type_idx, field_idx, value_type })
    None => None
  }
}

///|
priv struct OiStructAtomicReceiverFact {
  receiver_id : Int
}

///|
fn OiStructAtomicReceiverFact::from_expr(
  func : @ir.HotFunc,
  receiver_id : Int,
) -> OiStructAtomicReceiverFact? {
  // Binaryen's replacement can reuse the receiver via `getResultOfFirst` or a
  // fresh local. The current HOT OI-L surface keeps this fact deliberately
  // explicit and accepts only trivially duplicable receiver producers that prior
  // Binaryen probes exercised for Starshine: local.get and global.get.
  match @ir.hot_node_get(func, receiver_id).op {
    @ir.HotOp::LocalGet | @ir.HotOp::GlobalGet => Some({ receiver_id, })
    _ => None
  }
}

///|
priv struct OiStructAtomicIdentityOperandFact {
  value_id : Int
}

///|
fn OiStructAtomicIdentityOperandFact::from_rmw(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  field_fact : OiStructAtomicFieldFact,
  op : @lib.AggregateAtomicRmwOp,
  value_id : Int,
) -> OiStructAtomicIdentityOperandFact? {
  // Binaryen v130 folds RMW add/sub/or/xor with zero and and with all-ones to a
  // read-only struct.atomic.get when the value is a single constant fallthrough.
  // The HOT fact uses the existing literal facts for the represented i32/i64
  // field surface.
  let is_identity = match op {
    @lib.AggregateAtomicRmwAdd
    | @lib.AggregateAtomicRmwSub
    | @lib.AggregateAtomicRmwOr
    | @lib.AggregateAtomicRmwXor =>
      if field_fact.value_type == @lib.ValType::i32() {
        optimize_instructions_i32_const_is(func, dead, value_id, 0)
      } else {
        optimize_instructions_i64_const_is(func, dead, value_id, 0L)
      }
    @lib.AggregateAtomicRmwAnd =>
      if field_fact.value_type == @lib.ValType::i32() {
        optimize_instructions_i32_const_is(func, dead, value_id, -1)
      } else {
        optimize_instructions_i64_const_is(func, dead, value_id, -1L)
      }
    _ => false
  }
  if is_identity {
    Some({ value_id, })
  } else {
    None
  }
}

///|
priv struct OiStructAtomicCmpxchgSameValueFact {
  expected_id : Int
  replacement_id : Int
}

///|
fn OiStructAtomicCmpxchgSameValueFact::from_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  expected_id : Int,
  replacement_id : Int,
) -> OiStructAtomicCmpxchgSameValueFact? {
  // Binaryen v130 `visitStructCmpxchg` uses `areConsecutiveInputsEqual` to
  // prove that `expected` and `replacement` cannot modify the field and then
  // rewrites cmpxchg to a read-only struct.atomic.get. Starshine routes the
  // represented same-value cmpxchg surface through the shared consecutive-input
  // equality fact used by the OI-G bulk-memory facts: matching tee/get,
  // structurally identical pure scalar fallthrough trees, deterministic
  // state-read scalar trees, and effect-sensitive stable reads, with explicit
  // intervening-effect interference checks.
  let equality_fact = OiConsecutiveInputEqualityFact::from_adjacent_operands(
    ctx, func, expected_id, replacement_id,
  )
  if equality_fact.proves_equal(func) {
    Some({ expected_id, replacement_id })
  } else {
    None
  }
}

///|
fn optimize_instructions_try_rewrite_struct_atomic_identity_get(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  field_fact : OiStructAtomicFieldFact,
  receiver_fact : OiStructAtomicReceiverFact,
  operands_to_drop : Array[Int],
) -> Bool {
  let body : Array[Int] = []
  for operand in operands_to_drop {
    if !OiLiveNodeFact::proves_node_live(func, dead, operand) ||
      !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, operand) {
      return false
    }
    body.push(@ir.hot_build_drop(func, operand))
  }
  body.push(
    optimize_instructions_build_exact_atomic(
      func,
      @lib.Instruction::struct_atomic_get(
        @lib.AtomicOrder::seq_cst(),
        field_fact.type_idx,
        field_fact.field_idx,
      ),
      Some(field_fact.value_type),
      [receiver_fact.receiver_id],
    ),
  )
  optimize_instructions_replace_with_value_block(
    ctx,
    func,
    node_id,
    field_fact.value_type,
    body,
  )
  true
}

///|
priv enum OiStructAtomicRmwLoweringOpFact {
  StructAtomicRmwLowerAdd
  StructAtomicRmwLowerSub
  StructAtomicRmwLowerAnd
  StructAtomicRmwLowerOr
  StructAtomicRmwLowerXor
  StructAtomicRmwLowerXchg
}

///|
fn OiStructAtomicRmwLoweringOpFact::from_op(
  op : @lib.AggregateAtomicRmwOp,
) -> OiStructAtomicRmwLoweringOpFact? {
  // Binaryen v130 lowers all non-identity unshared struct RMW operators except
  // none: add/sub/and/or/xor become a struct.get, binary op, struct.set, and old
  // value; xchg stores the replacement value directly. This fact owns that
  // operator table so the visitor no longer hard-codes an add/xchg whitelist.
  match op {
    @lib.AggregateAtomicRmwAdd => Some(StructAtomicRmwLowerAdd)
    @lib.AggregateAtomicRmwSub => Some(StructAtomicRmwLowerSub)
    @lib.AggregateAtomicRmwAnd => Some(StructAtomicRmwLowerAnd)
    @lib.AggregateAtomicRmwOr => Some(StructAtomicRmwLowerOr)
    @lib.AggregateAtomicRmwXor => Some(StructAtomicRmwLowerXor)
    @lib.AggregateAtomicRmwXchg => Some(StructAtomicRmwLowerXchg)
  }
}

///|
fn OiStructAtomicRmwLoweringOpFact::build_new_value(
  self : OiStructAtomicRmwLoweringOpFact,
  func : @ir.HotFunc,
  value_type : @lib.ValType,
  old_get_for_new : Int,
  value_get_for_new : Int,
) -> Int? {
  match self {
    StructAtomicRmwLowerAdd =>
      optimize_instructions_build_exact_binary_for_value_type(
        func,
        value_type,
        @lib.Instruction::i32_add(),
        @lib.Instruction::i64_add(),
        old_get_for_new,
        value_get_for_new,
      )
    StructAtomicRmwLowerSub =>
      optimize_instructions_build_exact_binary_for_value_type(
        func,
        value_type,
        @lib.Instruction::i32_sub(),
        @lib.Instruction::i64_sub(),
        old_get_for_new,
        value_get_for_new,
      )
    StructAtomicRmwLowerAnd =>
      optimize_instructions_build_exact_binary_for_value_type(
        func,
        value_type,
        @lib.Instruction::i32_and(),
        @lib.Instruction::i64_and(),
        old_get_for_new,
        value_get_for_new,
      )
    StructAtomicRmwLowerOr =>
      optimize_instructions_build_exact_binary_for_value_type(
        func,
        value_type,
        @lib.Instruction::i32_or(),
        @lib.Instruction::i64_or(),
        old_get_for_new,
        value_get_for_new,
      )
    StructAtomicRmwLowerXor =>
      optimize_instructions_build_exact_binary_for_value_type(
        func,
        value_type,
        @lib.Instruction::i32_xor(),
        @lib.Instruction::i64_xor(),
        old_get_for_new,
        value_get_for_new,
      )
    StructAtomicRmwLowerXchg => Some(value_get_for_new)
  }
}

///|
fn optimize_instructions_try_rewrite_struct_atomic_rmw(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  op : @lib.AggregateAtomicRmwOp,
  field_fact : OiStructAtomicFieldFact,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 2 {
    return false
  }
  let receiver_id = @ir.hot_child_get(func, node_id, 0)
  let value_id = @ir.hot_child_get(func, node_id, 1)
  let identity_operand_fact = OiStructAtomicIdentityOperandFact::from_rmw(
    func, dead, field_fact, op, value_id,
  )
  match identity_operand_fact {
    Some(identity_fact) => {
      let receiver_fact = match
        OiStructAtomicReceiverFact::from_expr(func, receiver_id) {
        Some(fact) => fact
        None => return false
      }
      return optimize_instructions_try_rewrite_struct_atomic_identity_get(
        ctx,
        func,
        dead,
        node_id,
        field_fact,
        receiver_fact,
        [identity_fact.value_id],
      )
    }
    None => ()
  }
  let lowering_op = match OiStructAtomicRmwLoweringOpFact::from_op(op) {
    Some(fact) => fact
    None => return false
  }
  let receiver_fact = match
    OiStructAtomicReceiverFact::from_expr(func, receiver_id) {
    Some(fact) => fact
    None => return false
  }
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, value_id) {
    return false
  }
  let receiver_local = optimize_instructions_add_temp_local(
    func,
    @lib.ValType::ref_type(
      @lib.RefType::new(true, @lib.HeapType::new(field_fact.type_idx)),
    ),
  )
  let value_local = optimize_instructions_add_temp_local(
    func,
    field_fact.value_type,
  )
  let old_local = optimize_instructions_add_temp_local(
    func,
    field_fact.value_type,
  )
  let old_get_for_new = @ir.hot_build_local_get(func, old_local)
  let value_get_for_new = @ir.hot_build_local_get(func, value_local)
  let new_value = match
    lowering_op.build_new_value(
      func,
      field_fact.value_type,
      old_get_for_new,
      value_get_for_new,
    ) {
    Some(id) => id
    None => return false
  }
  let body : Array[Int] = [
    @ir.hot_build_local_set(func, receiver_local, receiver_fact.receiver_id),
    @ir.hot_build_local_set(func, value_local, value_id),
    @ir.hot_build_local_set(
      func,
      old_local,
      optimize_instructions_build_exact_heap(
        func,
        @lib.Instruction::struct_get(field_fact.type_idx, field_fact.field_idx),
        Some(field_fact.value_type),
        [@ir.hot_build_local_get(func, receiver_local)],
      ),
    ),
    optimize_instructions_build_exact_heap(
      func,
      @lib.Instruction::struct_set(field_fact.type_idx, field_fact.field_idx),
      None,
      [@ir.hot_build_local_get(func, receiver_local), new_value],
    ),
    @ir.hot_build_local_get(func, old_local),
  ]
  optimize_instructions_replace_with_value_block(
    ctx,
    func,
    node_id,
    field_fact.value_type,
    body,
  )
  true
}

///|
fn optimize_instructions_try_rewrite_struct_atomic_cmpxchg(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  field_fact : OiStructAtomicFieldFact,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 3 {
    return false
  }
  let receiver_id = @ir.hot_child_get(func, node_id, 0)
  let expected_id = @ir.hot_child_get(func, node_id, 1)
  let replacement_id = @ir.hot_child_get(func, node_id, 2)
  let same_value_fact = OiStructAtomicCmpxchgSameValueFact::from_operands(
    ctx, func, expected_id, replacement_id,
  )
  match same_value_fact {
    Some(fact) => {
      let receiver_fact = match
        OiStructAtomicReceiverFact::from_expr(func, receiver_id) {
        Some(fact) => fact
        None => return false
      }
      return optimize_instructions_try_rewrite_struct_atomic_identity_get(
        ctx,
        func,
        dead,
        node_id,
        field_fact,
        receiver_fact,
        [fact.expected_id, fact.replacement_id],
      )
    }
    None => ()
  }
  let receiver_fact = match
    OiStructAtomicReceiverFact::from_expr(func, receiver_id) {
    Some(fact) => fact
    None => return false
  }
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, expected_id) ||
    !OiSideEffectFreeExpressionFact::proves_node_free(
      func, dead, replacement_id,
    ) {
    return false
  }
  let receiver_local = optimize_instructions_add_temp_local(
    func,
    @lib.ValType::ref_type(
      @lib.RefType::new(true, @lib.HeapType::new(field_fact.type_idx)),
    ),
  )
  let expected_local = optimize_instructions_add_temp_local(
    func,
    field_fact.value_type,
  )
  let replacement_local = optimize_instructions_add_temp_local(
    func,
    field_fact.value_type,
  )
  let old_local = optimize_instructions_add_temp_local(
    func,
    field_fact.value_type,
  )
  let old_for_compare = @ir.hot_build_local_get(func, old_local)
  let expected_for_compare = @ir.hot_build_local_get(func, expected_local)
  let condition = match
    optimize_instructions_build_exact_compare_for_value_type(
      func,
      field_fact.value_type,
      @lib.Instruction::i32_eq(),
      @lib.Instruction::i64_eq(),
      old_for_compare,
      expected_for_compare,
    ) {
    Some(id) => id
    None => return false
  }
  let selected = @ir.hot_build_select(
    func,
    field_fact.value_type,
    @ir.hot_build_local_get(func, replacement_local),
    @ir.hot_build_local_get(func, old_local),
    condition,
  )
  let body : Array[Int] = [
    @ir.hot_build_local_set(func, receiver_local, receiver_fact.receiver_id),
    @ir.hot_build_local_set(func, expected_local, expected_id),
    @ir.hot_build_local_set(func, replacement_local, replacement_id),
    @ir.hot_build_local_set(
      func,
      old_local,
      optimize_instructions_build_exact_heap(
        func,
        @lib.Instruction::struct_get(field_fact.type_idx, field_fact.field_idx),
        Some(field_fact.value_type),
        [@ir.hot_build_local_get(func, receiver_local)],
      ),
    ),
    optimize_instructions_build_exact_heap(
      func,
      @lib.Instruction::struct_set(field_fact.type_idx, field_fact.field_idx),
      None,
      [@ir.hot_build_local_get(func, receiver_local), selected],
    ),
    @ir.hot_build_local_get(func, old_local),
  ]
  optimize_instructions_replace_with_value_block(
    ctx,
    func,
    node_id,
    field_fact.value_type,
    body,
  )
  true
}

///|
fn optimize_instructions_try_rewrite_aggregate_atomic(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let instr = match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) => instr
    None => return false
  }
  match instr {
    @lib.Instruction::StructAtomicRmw(op, type_idx, field_idx) => {
      let field_fact = match
        OiStructAtomicFieldFact::from_index(ctx, type_idx, field_idx) {
        Some(fact) => fact
        None => return false
      }
      optimize_instructions_try_rewrite_struct_atomic_rmw(
        ctx, func, dead, node_id, op, field_fact,
      )
    }
    @lib.Instruction::StructAtomicCmpxchg(type_idx, field_idx) => {
      let field_fact = match
        OiStructAtomicFieldFact::from_index(ctx, type_idx, field_idx) {
        Some(fact) => fact
        None => return false
      }
      optimize_instructions_try_rewrite_struct_atomic_cmpxchg(
        ctx, func, dead, node_id, field_fact,
      )
    }
    @lib.Instruction::ArrayAtomicRmw(_, _)
    | @lib.Instruction::ArrayAtomicCmpxchg(_) => false
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_const_memory_access_offset(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  ignore(dead)
  match OiMemoryOffsetFoldRewritePlanFact::from_node(func, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_packed_i32_const(
  raw : Int,
  bits : Int,
  signed : Bool,
) -> @lib.I32 {
  let mask = (1 << bits) - 1
  let truncated = raw & mask
  if signed {
    let sign = 1 << (bits - 1)
    if (truncated & sign) != 0 {
      @lib.I32(truncated - (1 << bits))
    } else {
      @lib.I32(truncated)
    }
  } else {
    @lib.I32(truncated)
  }
}

///|
fn optimize_instructions_packed_storage_bits(
  storage_type : @lib.StorageType,
) -> Int? {
  match storage_type {
    @lib.PackTypeStorageType(@lib.I8PackType) => Some(8)
    @lib.PackTypeStorageType(@lib.I16PackType) => Some(16)
    _ => None
  }
}

///|
fn optimize_instructions_struct_field_pack_bits(
  ctx : HotPassContext,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  if field_idx < 0 || field_idx >= fields.length() {
    return None
  }
  optimize_instructions_packed_storage_bits(
    fields[field_idx].get_storage_type(),
  )
}

///|
fn optimize_instructions_array_field_pack_bits(
  ctx : HotPassContext,
  type_idx : @lib.TypeIdx,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let field = match @ir.hot_module_resolve_array_field(module_ctx, type_idx) {
    Some(field) => field
    None => return None
  }
  optimize_instructions_packed_storage_bits(field.get_storage_type())
}

///|
fn optimize_instructions_default_value_for_storage(
  func : @ir.HotFunc,
  storage : @lib.StorageType,
) -> Int? {
  match storage.unpack() {
    @lib.ValType::NumTypeValType(@lib.NumType::I32NumType) =>
      Some(@ir.hot_build_const_i32(func, @lib.I32(0)))
    @lib.ValType::NumTypeValType(@lib.NumType::I64NumType) =>
      Some(@ir.hot_build_const_i64(func, @lib.I64(0L)))
    @lib.ValType::NumTypeValType(@lib.NumType::F32NumType) =>
      Some(@ir.hot_build_const_f32(func, @lib.F32(0.0)))
    @lib.ValType::NumTypeValType(@lib.NumType::F64NumType) =>
      Some(@ir.hot_build_const_f64(func, @lib.F64(0.0)))
    @lib.ValType::VecTypeValType => Some(@ir.hot_build_const_v128_zero(func))
    @lib.ValType::RefTypeValType(ref_type) =>
      if ref_type.is_nullable() {
        Some(@ir.hot_build_ref_null(func, ref_type))
      } else {
        None
      }
    @lib.ValType::BotValType => None
  }
}

///|
fn optimize_instructions_struct_default_field_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  type_idx : @lib.TypeIdx,
  field_idx : Int,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let fields = match
    @ir.hot_module_resolve_struct_fields(module_ctx, type_idx) {
    Some(fields) => fields
    None => return None
  }
  if field_idx < 0 || field_idx >= fields.length() {
    return None
  }
  optimize_instructions_default_value_for_storage(
    func,
    fields[field_idx].get_storage_type(),
  )
}

///|
fn optimize_instructions_array_default_element_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  type_idx : @lib.TypeIdx,
) -> Int? {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return None
  }
  let field = match @ir.hot_module_resolve_array_field(module_ctx, type_idx) {
    Some(field) => field
    None => return None
  }
  optimize_instructions_default_value_for_storage(
    func,
    field.get_storage_type(),
  )
}

///|
fn optimize_instructions_replace_with_packed_i32_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  value_id : Int,
  bits : Int,
  signed : Bool,
) -> Unit {
  match optimize_instructions_i32_const(func, dead, value_id) {
    Some(@lib.I32(raw)) =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        optimize_instructions_packed_i32_const(raw, bits, signed),
      )
    None =>
      if signed {
        let instr = if bits == 8 {
          @lib.Instruction::i32_extend8s()
        } else {
          @lib.Instruction::i32_extend16s()
        }
        optimize_instructions_replace_with_exact_unary(
          ctx, func, node_id, instr, value_id,
        )
      } else {
        let mask = if bits == 8 { 255 } else { 65535 }
        let replacement = optimize_instructions_build_i32_binary(
          func,
          @lib.Instruction::i32_and(),
          value_id,
          @ir.hot_build_const_i32(func, @lib.I32(mask)),
        )
        optimize_instructions_replace_with_node_id(
          ctx, func, node_id, replacement,
        )
      }
  }
}

///|
priv enum OiTupleLaneLocalizeFact {
  TupleLaneDirectLocalizable
  TupleLaneControlBoundary
}

///|
fn OiTupleLaneLocalizeFact::allows_direct(
  self : OiTupleLaneLocalizeFact,
) -> Bool {
  match self {
    TupleLaneDirectLocalizable => true
    TupleLaneControlBoundary => false
  }
}

///|
fn OiTupleLaneLocalizeFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiTupleLaneLocalizeFact {
  // Binaryen v130 `visitTupleExtract` delegates discarded-value sequencing to
  // `getDroppedChildrenAndAppend(make, get)`, which can localize expression
  // children but must not synthesize through structured control, branches,
  // returns, or EH roots. Keep that boundary as an explicit tuple-lane fact
  // instead of an open-ended tuple scanner whitelist.
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for i = 0; i < @ir.hot_region_root_count(func, body); i = i + 1 {
        if !OiTupleLaneLocalizeFact::from_node(
            func,
            @ir.hot_region_get(func, body, i),
          ).allows_direct() {
          return TupleLaneControlBoundary
        }
      }
      return TupleLaneDirectLocalizable
    }
    @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Catch
    | @ir.HotOp::CatchAll => return TupleLaneControlBoundary
    _ => ()
  }
  for child_idx = 0; child_idx < node.child_count; child_idx = child_idx + 1 {
    let child_id = @ir.hot_child_get(func, node_id, child_idx)
    if child_id >= 0 &&
      !OiTupleLaneLocalizeFact::from_node(func, child_id).allows_direct() {
      return TupleLaneControlBoundary
    }
  }
  TupleLaneDirectLocalizable
}

///|
priv enum OiTupleLaneTrapFact {
  TupleLaneMayTrapWithoutEffectMask
  TupleLaneNoKnownTrapWithoutEffectMask
}

///|
fn OiTupleLaneTrapFact::may_trap(self : OiTupleLaneTrapFact) -> Bool {
  match self {
    TupleLaneMayTrapWithoutEffectMask => true
    TupleLaneNoKnownTrapWithoutEffectMask => false
  }
}

///|
fn OiTupleLaneTrapFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiTupleLaneTrapFact {
  // This is the tuple-local Binaryen `getDroppedChildrenAndAppend` preservation
  // fact for pure instructions that still may trap when dropped as an unselected
  // lane. It intentionally remains narrower than general EffectAnalyzer facts.
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(
      @lib.Instruction::I32DivS
      | @lib.Instruction::I32DivU
      | @lib.Instruction::I32RemS
      | @lib.Instruction::I32RemU
      | @lib.Instruction::I64DivS
      | @lib.Instruction::I64DivU
      | @lib.Instruction::I64RemS
      | @lib.Instruction::I64RemU
      | @lib.Instruction::RefAsNonNull
      | @lib.Instruction::I31GetS
      | @lib.Instruction::I31GetU
    ) => return TupleLaneMayTrapWithoutEffectMask
    _ => ()
  }
  let node = @ir.hot_node_get(func, node_id)
  for child_idx = 0; child_idx < node.child_count; child_idx = child_idx + 1 {
    let child_id = @ir.hot_child_get(func, node_id, child_idx)
    if child_id >= 0 &&
      OiTupleLaneTrapFact::from_node(func, child_id).may_trap() {
      return TupleLaneMayTrapWithoutEffectMask
    }
  }
  TupleLaneNoKnownTrapWithoutEffectMask
}

///|
priv enum OiTupleLaneDiscardFact {
  TupleLaneCanEraseWhenDiscarded
  TupleLaneMustPreserveWhenDiscarded
}

///|
fn OiTupleLaneDiscardFact::must_preserve(self : OiTupleLaneDiscardFact) -> Bool {
  match self {
    TupleLaneCanEraseWhenDiscarded => false
    TupleLaneMustPreserveWhenDiscarded => true
  }
}

///|
fn OiTupleLaneDiscardFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  localize_fact : OiTupleLaneLocalizeFact,
) -> OiTupleLaneDiscardFact {
  if !localize_fact.allows_direct() {
    return TupleLaneMustPreserveWhenDiscarded
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for i = 0; i < @ir.hot_region_root_count(func, body); i = i + 1 {
        let child_id = @ir.hot_region_get(func, body, i)
        let child_localize = OiTupleLaneLocalizeFact::from_node(func, child_id)
        if OiTupleLaneDiscardFact::from_node(
            ctx, func, child_id, child_localize,
          ).must_preserve() {
          return TupleLaneMustPreserveWhenDiscarded
        }
      }
      return TupleLaneCanEraseWhenDiscarded
    }
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Catch
    | @ir.HotOp::CatchAll => return TupleLaneMustPreserveWhenDiscarded
    _ => ()
  }
  if !optimize_instructions_node_effects_are_pure(ctx, func, node_id) ||
    OiTupleLaneTrapFact::from_node(func, node_id).may_trap() {
    TupleLaneMustPreserveWhenDiscarded
  } else {
    TupleLaneCanEraseWhenDiscarded
  }
}

///|
fn optimize_instructions_tuple_extract_child_for_flat_index(
  func : @ir.HotFunc,
  tuple_id : Int,
  index : Int,
) -> (Int, Int)? {
  let tuple = @ir.hot_node_get(func, tuple_id)
  let mut first_result = 0
  for slot = 0; slot < tuple.child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, tuple_id, slot)
    let child_results = @ir.hot_type_results(
      func,
      @ir.hot_node_get(func, child_id).ty,
    )
    let next_result = first_result + child_results.length()
    if index >= first_result && index < next_result {
      return Some((slot, index - first_result))
    }
    first_result = next_result
  }
  None
}

///|
priv enum OiTupleLaneMaterializeFact {
  TupleLaneEraseDiscarded
  TupleLaneAppendEffectRoot
  TupleLaneDropSingleResult
  TupleLaneStoreMultiResultLocals
}

///|
fn OiTupleLaneMaterializeFact::from_lane(
  results : Array[@lib.ValType],
  discard_fact : OiTupleLaneDiscardFact,
) -> OiTupleLaneMaterializeFact {
  // Binaryen v130 `getDroppedChildrenAndAppend` materializes discarded tuple
  // lanes by preserving no-result effects directly, dropping single-result
  // effects, or storing each result of a multivalue effect into scratch locals.
  // Keep that emission choice as a tuple-lane fact instead of a body-builder
  // side branch hidden inside the tuple.extract rewrite.
  if !discard_fact.must_preserve() {
    return TupleLaneEraseDiscarded
  }
  match results.length() {
    0 => TupleLaneAppendEffectRoot
    1 => TupleLaneDropSingleResult
    _ => TupleLaneStoreMultiResultLocals
  }
}

///|
fn OiTupleLaneMaterializeFact::must_emit(
  self : OiTupleLaneMaterializeFact,
) -> Bool {
  match self {
    TupleLaneEraseDiscarded => false
    TupleLaneAppendEffectRoot
    | TupleLaneDropSingleResult
    | TupleLaneStoreMultiResultLocals => true
  }
}

///|
fn OiTupleLaneMaterializeFact::append_discarded_child(
  self : OiTupleLaneMaterializeFact,
  func : @ir.HotFunc,
  child_id : Int,
  child_results : Array[@lib.ValType],
  body : Array[Int],
) -> Unit {
  match self {
    TupleLaneEraseDiscarded => ()
    TupleLaneAppendEffectRoot => body.push(child_id)
    TupleLaneDropSingleResult => body.push(@ir.hot_build_drop(func, child_id))
    TupleLaneStoreMultiResultLocals => {
      let discard_locals : Array[Int] = []
      for result in child_results {
        discard_locals.push(@ir.hot_append_body_local(func, result))
      }
      let mut lane = child_results.length()
      while lane > 0 {
        lane = lane - 1
        body.push(@ir.hot_build_local_set(func, discard_locals[lane], child_id))
      }
    }
  }
}

///|
priv struct OiTupleLaneFact {
  node_id : Int
  results : Array[@lib.ValType]
  localize_fact : OiTupleLaneLocalizeFact
  discard_fact : OiTupleLaneDiscardFact
  materialize_fact : OiTupleLaneMaterializeFact
}

///|
fn OiTupleLaneFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiTupleLaneFact {
  let localize_fact = OiTupleLaneLocalizeFact::from_node(func, node_id)
  let results = @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))
  let discard_fact = OiTupleLaneDiscardFact::from_node(
    ctx, func, node_id, localize_fact,
  )
  {
    node_id,
    results,
    localize_fact,
    discard_fact,
    materialize_fact: OiTupleLaneMaterializeFact::from_lane(
      results, discard_fact,
    ),
  }
}

///|
priv struct OiTupleExtractEligibilityFact {
  tuple_id : Int
  index : Int
}

///|
fn OiTupleExtractEligibilityFact::from_extract(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiTupleExtractEligibilityFact? {
  // Binaryen v130 `visitTupleExtract` only rewrites a `tuple.extract` fed by a
  // single-use `tuple.make` with a concrete lane index. Keep those structural
  // gates in an explicit eligibility fact so the tuple rewrite fact owns only
  // source-backed lane/discard/materialization decisions.
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::TupleExtract if node.child_count == 1 => ()
    _ => return None
  }
  let tuple_id = @ir.hot_child_get(func, node_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, tuple_id) ||
    pass_node_use_count(ctx, func, tuple_id) != 1 {
    return None
  }
  let tuple = @ir.hot_node_get(func, tuple_id)
  match tuple.op {
    @ir.HotOp::TupleMake => ()
    _ => return None
  }
  let index = node.imm0
  if index < 0 {
    return None
  }
  Some({ tuple_id, index })
}

///|
priv struct OiTupleSiblingEffectFact {
  has_preserved_sibling : Bool
  has_later_preserved_sibling : Bool
}

///|
fn OiTupleSiblingEffectFact::from_lanes(
  lane_facts : Array[OiTupleLaneFact],
  selected_slot : Int,
) -> OiTupleSiblingEffectFact {
  // Binaryen v130 `visitTupleExtract` rewrites the selected tuple lane to a
  // temporary and lets `getDroppedChildrenAndAppend(make, get)` preserve only
  // discarded siblings whose effects/traps must remain observable. Keep the
  // sibling-order summary as an explicit fact so direct selected-lane
  // forwarding and selected-lane materialization consume the same source-backed
  // evidence instead of re-scanning tuple lanes independently.
  let mut has_preserved_sibling = false
  let mut has_later_preserved_sibling = false
  for slot = 0; slot < lane_facts.length(); slot = slot + 1 {
    if slot == selected_slot {
      continue
    }
    if lane_facts[slot].discard_fact.must_preserve() {
      has_preserved_sibling = true
      if slot > selected_slot {
        has_later_preserved_sibling = true
      }
    }
  }
  { has_preserved_sibling, has_later_preserved_sibling }
}

///|
fn OiTupleSiblingEffectFact::allows_selected_forward(
  self : OiTupleSiblingEffectFact,
) -> Bool {
  !self.has_preserved_sibling
}

///|
fn OiTupleSiblingEffectFact::needs_selected_local(
  self : OiTupleSiblingEffectFact,
) -> Bool {
  self.has_later_preserved_sibling
}

///|
priv struct OiTupleExtractFact {
  selected_slot : Int
  selected_lane : Int
  selected_id : Int
  selected_results : Array[@lib.ValType]
  lane_facts : Array[OiTupleLaneFact]
  sibling_effect_fact : OiTupleSiblingEffectFact
}

///|
fn OiTupleExtractFact::from_extract(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiTupleExtractFact? {
  let eligibility = match
    OiTupleExtractEligibilityFact::from_extract(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return None
  }
  let tuple_id = eligibility.tuple_id
  let tuple = @ir.hot_node_get(func, tuple_id)
  let index = eligibility.index
  let lane_facts : Array[OiTupleLaneFact] = []
  for slot = 0; slot < tuple.child_count; slot = slot + 1 {
    let lane_fact = OiTupleLaneFact::from_node(
      ctx,
      func,
      @ir.hot_child_get(func, tuple_id, slot),
    )
    if !lane_fact.localize_fact.allows_direct() {
      return None
    }
    lane_facts.push(lane_fact)
  }
  let (selected_slot, selected_lane) = match
    optimize_instructions_tuple_extract_child_for_flat_index(
      func, tuple_id, index,
    ) {
    Some(value) => value
    None => return None
  }
  let selected_fact = lane_facts[selected_slot]
  if selected_fact.results.length() == 0 {
    return None
  }
  Some({
    selected_slot,
    selected_lane,
    selected_id: selected_fact.node_id,
    selected_results: selected_fact.results,
    sibling_effect_fact: OiTupleSiblingEffectFact::from_lanes(
      lane_facts, selected_slot,
    ),
    lane_facts,
  })
}

///|
fn OiTupleExtractFact::can_forward_selected_directly(
  self : OiTupleExtractFact,
) -> Bool {
  self.sibling_effect_fact.allows_selected_forward() &&
  self.selected_results.length() == 1
}

///|
priv struct OiTupleSelectedMaterializeFact {
  selected_local : Int
  selected_result_locals : Array[Int]
}

///|
fn OiTupleSelectedMaterializeFact::from_extract(
  func : @ir.HotFunc,
  tuple_fact : OiTupleExtractFact,
) -> OiTupleSelectedMaterializeFact {
  // Binaryen v130 `visitTupleExtract` stores the selected lane in a temporary
  // local tee before delegating dropped sibling sequencing to
  // `getDroppedChildrenAndAppend(make, get)`. Starshine's HOT tuple shape can
  // directly forward the selected child when no later preserved sibling can
  // reorder around it, but the selected-lane materialization choice still lives
  // in an explicit fact rather than the tuple body builder.
  let mut selected_local = -1
  let selected_result_locals : Array[Int] = []
  if tuple_fact.selected_results.length() > 1 {
    for result in tuple_fact.selected_results {
      selected_result_locals.push(@ir.hot_append_body_local(func, result))
    }
  } else if tuple_fact.sibling_effect_fact.needs_selected_local() {
    selected_local = @ir.hot_append_body_local(
      func,
      tuple_fact.selected_results[0],
    )
  }
  { selected_local, selected_result_locals }
}

///|
fn OiTupleSelectedMaterializeFact::needs_selected_local(
  self : OiTupleSelectedMaterializeFact,
) -> Bool {
  self.selected_local >= 0
}

///|
fn OiTupleSelectedMaterializeFact::has_selected_result_locals(
  self : OiTupleSelectedMaterializeFact,
) -> Bool {
  self.selected_result_locals.length() > 0
}

///|
fn OiTupleSelectedMaterializeFact::append_selected_capture(
  self : OiTupleSelectedMaterializeFact,
  func : @ir.HotFunc,
  tuple_fact : OiTupleExtractFact,
  body : Array[Int],
) -> Unit {
  if self.has_selected_result_locals() {
    let mut lane = tuple_fact.selected_results.length()
    while lane > 0 {
      lane = lane - 1
      body.push(
        @ir.hot_build_local_set(
          func,
          self.selected_result_locals[lane],
          tuple_fact.selected_id,
        ),
      )
    }
  } else if self.needs_selected_local() {
    body.push(
      @ir.hot_build_local_set(func, self.selected_local, tuple_fact.selected_id),
    )
  }
}

///|
fn OiTupleSelectedMaterializeFact::append_selected_result(
  self : OiTupleSelectedMaterializeFact,
  func : @ir.HotFunc,
  tuple_fact : OiTupleExtractFact,
  body : Array[Int],
) -> Unit {
  if self.has_selected_result_locals() {
    body.push(
      @ir.hot_build_local_get(
        func,
        self.selected_result_locals[tuple_fact.selected_lane],
      ),
    )
  } else if self.needs_selected_local() {
    body.push(@ir.hot_build_local_get(func, self.selected_local))
  } else {
    body.push(tuple_fact.selected_id)
  }
}

///|
priv enum OiTupleExtractRewritePlanKind {
  TupleExtractForwardSelected
  TupleExtractMaterializeSelected
}

///|
priv struct OiTupleExtractRewritePlanFact {
  kind : OiTupleExtractRewritePlanKind
  tuple_fact : OiTupleExtractFact
  selected_materialize_fact : OiTupleSelectedMaterializeFact?
}

///|
fn OiTupleExtractRewritePlanFact::from_extract(
  func : @ir.HotFunc,
  tuple_fact : OiTupleExtractFact,
) -> OiTupleExtractRewritePlanFact {
  // Binaryen v130 `visitTupleExtract` either forwards the selected child when
  // sibling preservation is unnecessary or materializes the selected child
  // before `getDroppedChildrenAndAppend` emits preserved discarded lanes. Keep
  // that visitor-level choice as an explicit plan fact instead of a body-builder
  // branch in the pass visitor.
  if tuple_fact.can_forward_selected_directly() {
    return {
      kind: TupleExtractForwardSelected,
      tuple_fact,
      selected_materialize_fact: None,
    }
  }
  {
    kind: TupleExtractMaterializeSelected,
    tuple_fact,
    selected_materialize_fact: Some(
      OiTupleSelectedMaterializeFact::from_extract(func, tuple_fact),
    ),
  }
}

///|
fn OiTupleExtractRewritePlanFact::apply(
  self : OiTupleExtractRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    TupleExtractForwardSelected => {
      optimize_instructions_replace_with_node_id(
        ctx,
        func,
        node_id,
        self.tuple_fact.selected_id,
      )
      true
    }
    TupleExtractMaterializeSelected =>
      self.apply_materialized(ctx, func, node_id)
  }
}

///|
fn OiTupleExtractRewritePlanFact::apply_materialized(
  self : OiTupleExtractRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let selected_materialize_fact = match self.selected_materialize_fact {
    Some(fact) => fact
    None => return false
  }
  let body : Array[Int] = []
  for slot = 0; slot < self.tuple_fact.lane_facts.length(); slot = slot + 1 {
    let lane_fact = self.tuple_fact.lane_facts[slot]
    if slot == self.tuple_fact.selected_slot {
      selected_materialize_fact.append_selected_capture(
        func,
        self.tuple_fact,
        body,
      )
      continue
    }
    if !lane_fact.materialize_fact.must_emit() {
      continue
    }
    lane_fact.materialize_fact.append_discarded_child(
      func,
      lane_fact.node_id,
      lane_fact.results,
      body,
    )
  }
  selected_materialize_fact.append_selected_result(func, self.tuple_fact, body)
  let replacement = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(
      self.tuple_fact.selected_results[self.tuple_fact.selected_lane],
    ),
    body,
  )
  optimize_instructions_replace_with_node_id(ctx, func, node_id, replacement)
  true
}

///|
fn optimize_instructions_try_fold_tuple_extract_tuple_make(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let tuple_fact = match
    OiTupleExtractFact::from_extract(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return false
  }
  OiTupleExtractRewritePlanFact::from_extract(func, tuple_fact).apply(
    ctx, func, node_id,
  )
}

///|
priv struct OiArrayNonTrappingLengthFact {
  known_non_trapping : Bool
}

///|
fn OiArrayNonTrappingLengthFact::from_len(
  len : Int,
) -> OiArrayNonTrappingLengthFact {
  // Binaryen version_130 keeps fresh array lengths above this O4z-observed
  // limit to preserve allocation trap behavior. Keep the threshold as an
  // explicit allocation fact so array_len/get/set folds all share the same
  // trap-preservation evidence.
  { known_non_trapping: len >= 0 && len <= 44739241 }
}

///|
fn OiArrayNonTrappingLengthFact::proves_known_non_trapping(
  self : OiArrayNonTrappingLengthFact,
) -> Bool {
  self.known_non_trapping
}

///|
fn OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
  len : Int,
) -> Bool {
  OiArrayNonTrappingLengthFact::from_len(len).proves_known_non_trapping()
}

///|
priv enum OiOrderedOperandControlShapeFact {
  OrderedOperandExpressionRoot
  OrderedOperandControlBoundary
}

///|
fn OiOrderedOperandControlShapeFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiOrderedOperandControlShapeFact {
  // Binaryen v130 ordered-effect rewrites rely on ChildLocalizer-like
  // root-shape facts: scalar expression roots can be sequenced by appending
  // their effects, while structured control, branches, returns, and EH roots
  // need a broader control-aware localizer. Keep that boundary as an explicit
  // fact rather than a helper-owned opcode predicate.
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Catch
    | @ir.HotOp::CatchAll => OrderedOperandControlBoundary
    _ => OrderedOperandExpressionRoot
  }
}

///|
fn OiOrderedOperandControlShapeFact::allows_order_preservation(
  self : OiOrderedOperandControlShapeFact,
) -> Bool {
  match self {
    OrderedOperandExpressionRoot => true
    OrderedOperandControlBoundary => false
  }
}

///|
priv enum OiOrderedOperandDiscardFact {
  OrderedOperandAppendEffectRoot
  OrderedOperandDropSingleResult
  OrderedOperandUnsupportedMultiResult
}

///|
fn OiOrderedOperandDiscardFact::from_results(
  results : Array[@lib.ValType],
) -> OiOrderedOperandDiscardFact {
  // Binaryen v130 `getDroppedChildrenAndAppend` can preserve a no-result
  // effect root directly or drop a single-result effect. Starshine's current
  // ordered-effect fact boundary does not synthesize scratch locals for
  // multi-result operands, so keep that unsupported case visible as a fact.
  match results.length() {
    0 => OrderedOperandAppendEffectRoot
    1 => OrderedOperandDropSingleResult
    _ => OrderedOperandUnsupportedMultiResult
  }
}

///|
fn OiOrderedOperandDiscardFact::can_materialize_ordered_effect(
  self : OiOrderedOperandDiscardFact,
) -> Bool {
  match self {
    OrderedOperandAppendEffectRoot | OrderedOperandDropSingleResult => true
    OrderedOperandUnsupportedMultiResult => false
  }
}

///|
fn OiOrderedOperandDiscardFact::append(
  self : OiOrderedOperandDiscardFact,
  func : @ir.HotFunc,
  node_id : Int,
  body : Array[Int],
) -> Bool {
  match self {
    OrderedOperandAppendEffectRoot => body.push(node_id)
    OrderedOperandDropSingleResult =>
      body.push(@ir.hot_build_drop(func, node_id))
    OrderedOperandUnsupportedMultiResult => return false
  }
  true
}

///|
priv struct OiOrderedOperandFact {
  node_id : Int
  results : Array[@lib.ValType]
  control_shape_fact : OiOrderedOperandControlShapeFact
  discard_fact : OiOrderedOperandDiscardFact
  is_trivially_pure : Bool
  is_effect_pure : Bool
}

///|
fn OiOrderedOperandFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiOrderedOperandFact {
  let effects = pass_require_effects(ctx, func)
  let results = @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))
  {
    node_id,
    results,
    control_shape_fact: OiOrderedOperandControlShapeFact::from_node(
      func, node_id,
    ),
    discard_fact: OiOrderedOperandDiscardFact::from_results(results),
    is_trivially_pure: OiTriviallyPureOperandFact::proves_node_pure(
      func, node_id,
    ),
    is_effect_pure: OiNodeEffectPurityFact::from_node_masks(
      effects.node_masks,
      node_id,
    ).proves_pure(),
  }
}

///|
fn OiOrderedOperandFact::is_pure(self : OiOrderedOperandFact) -> Bool {
  self.is_trivially_pure || self.is_effect_pure
}

///|
fn OiOrderedOperandFact::can_preserve_order(
  self : OiOrderedOperandFact,
) -> Bool {
  self.control_shape_fact.allows_order_preservation() &&
  self.discard_fact.can_materialize_ordered_effect()
}

///|
fn OiOrderedOperandFact::can_preserve_scalar_selected_value(
  self : OiOrderedOperandFact,
) -> Bool {
  self.control_shape_fact.allows_order_preservation() &&
  self.results.length() == 1
}

///|
fn OiOrderedOperandFact::append_discard(
  self : OiOrderedOperandFact,
  func : @ir.HotFunc,
  body : Array[Int],
) -> Bool {
  self.discard_fact.append(func, self.node_id, body)
}

///|
priv struct OiOrderedSelectedSiblingEffectFact {
  has_effectful_non_selected : Bool
  has_later_effectful_non_selected : Bool
}

///|
fn OiOrderedSelectedSiblingEffectFact::from_operands(
  operand_facts : Array[OiOrderedOperandFact],
  selected_index : Int,
) -> OiOrderedSelectedSiblingEffectFact {
  // Forward-selected and null-trap rewrites use the same Binaryen-shaped order
  // evidence as tuple extraction: pure siblings can disappear, earlier
  // effectful siblings are emitted before the selected value, and later
  // effectful siblings force selected-value localization. Keep that sibling
  // summary reusable instead of recomputing booleans in each selected-operand
  // rewrite helper.
  let mut has_effectful_non_selected = false
  let mut has_later_effectful_non_selected = false
  for i = 0; i < operand_facts.length(); i = i + 1 {
    if i == selected_index || operand_facts[i].is_pure() {
      continue
    }
    has_effectful_non_selected = true
    if i > selected_index {
      has_later_effectful_non_selected = true
    }
  }
  { has_effectful_non_selected, has_later_effectful_non_selected }
}

///|
fn OiOrderedSelectedSiblingEffectFact::allows_direct_forward(
  self : OiOrderedSelectedSiblingEffectFact,
) -> Bool {
  !self.has_effectful_non_selected
}

///|
fn OiOrderedSelectedSiblingEffectFact::needs_selected_local(
  self : OiOrderedSelectedSiblingEffectFact,
) -> Bool {
  self.has_later_effectful_non_selected
}

///|
fn optimize_instructions_append_ordered_effects(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  operand_ids : Array[Int],
  body : Array[Int],
) -> Bool {
  for operand_id in operand_ids {
    let operand_fact = OiOrderedOperandFact::from_node(ctx, func, operand_id)
    if !operand_fact.can_preserve_order() {
      return false
    }
    if operand_fact.is_pure() {
      continue
    }
    if !operand_fact.append_discard(func, body) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_try_replace_with_ordered_effects_then_void(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_ids : Array[Int],
  append_unreachable : Bool,
) -> Bool {
  let body : Array[Int] = []
  if !optimize_instructions_append_ordered_effects(ctx, func, operand_ids, body) {
    return false
  }
  if append_unreachable {
    if body.length() == 0 {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      return true
    }
    body.push(@ir.hot_build_unreachable(func))
  } else if body.length() == 0 {
    optimize_instructions_replace_with_nop(ctx, func, node_id)
    return true
  }
  let replacement = @ir.hot_build_block(func, @lib.BlockType::void_(), body)
  let replacement_node = @ir.hot_node_get(func, replacement)
  @ir.hot_replace_node(func, node_id, replacement_node)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_replace_with_ordered_effects_then_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_ids : Array[Int],
) -> Bool {
  let body : Array[Int] = []
  if !optimize_instructions_append_ordered_effects(ctx, func, operand_ids, body) {
    return false
  }
  if body.length() == 0 {
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
    return true
  }
  body.push(@ir.hot_build_unreachable(func))
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let replacement = @ir.hot_build_block(func, block_type, body)
  let replacement_node = @ir.hot_node_get(func, replacement)
  @ir.hot_replace_node(func, node_id, replacement_node)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_replace_with_ordered_effects_then_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_ids : Array[Int],
  value : @lib.I32,
) -> Bool {
  let body : Array[Int] = []
  if !optimize_instructions_append_ordered_effects(ctx, func, operand_ids, body) {
    return false
  }
  if body.length() == 0 {
    optimize_instructions_replace_with_const_i32(ctx, func, node_id, value)
    return true
  }
  body.push(@ir.hot_build_const_i32(func, value))
  let replacement = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    body,
  )
  let replacement_node = @ir.hot_node_get(func, replacement)
  @ir.hot_replace_node(func, node_id, replacement_node)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_forward_selected_operand_preserving_effects(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_ids : Array[Int],
  selected_index : Int,
) -> Bool {
  if selected_index < 0 || selected_index >= operand_ids.length() {
    return false
  }
  let result_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [val_type] => val_type
    _ => return false
  }
  let operand_facts : Array[OiOrderedOperandFact] = []
  for operand_id in operand_ids {
    let operand_fact = OiOrderedOperandFact::from_node(ctx, func, operand_id)
    if !operand_fact.can_preserve_order() {
      return false
    }
    operand_facts.push(operand_fact)
  }
  let selected_fact = operand_facts[selected_index]
  let selected_value_type = match selected_fact.results {
    [val_type] => val_type
    _ => return false
  }
  let sibling_effect_fact = OiOrderedSelectedSiblingEffectFact::from_operands(
    operand_facts, selected_index,
  )
  if sibling_effect_fact.allows_direct_forward() {
    optimize_instructions_replace_with_node_id(
      ctx,
      func,
      node_id,
      selected_fact.node_id,
    )
    return true
  }
  let body : Array[Int] = []
  let mut selected_local = -1
  let mut selected_result_id = selected_fact.node_id
  if sibling_effect_fact.needs_selected_local() {
    let local_type = match
      optimize_instructions_defaultable_scratch_type(selected_value_type) {
      Some(local_type) => local_type
      None => return false
    }
    selected_local = @ir.hot_append_body_local(func, local_type)
    let selected_get = @ir.hot_build_local_get(func, selected_local)
    selected_result_id = match
      optimize_instructions_restore_localized_result(
        func, selected_get, local_type, result_type,
      ) {
      Some(result_id) => result_id
      None => return false
    }
  } else if selected_value_type != result_type {
    return false
  }
  for i = 0; i < operand_facts.length(); i = i + 1 {
    let operand_fact = operand_facts[i]
    if i == selected_index {
      if sibling_effect_fact.needs_selected_local() {
        body.push(
          @ir.hot_build_local_set(func, selected_local, selected_fact.node_id),
        )
      } else {
        body.push(selected_fact.node_id)
      }
      continue
    }
    if operand_fact.is_pure() {
      continue
    }
    if !operand_fact.append_discard(func, body) {
      return false
    }
  }
  if sibling_effect_fact.needs_selected_local() {
    body.push(selected_result_id)
  }
  let replacement = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(result_type),
    body,
  )
  let replacement_node = @ir.hot_node_get(func, replacement)
  @ir.hot_replace_node(func, node_id, replacement_node)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
priv struct OiChildLocalizationPlanFact {
  source_ids : Array[Int]
  drop_ids : Array[Int]
}

///|
priv struct OiArrayNewFixedRepeatedValueFact {
  node_id : Int
  type_idx : @lib.TypeIdx
  size : Int
  representative_id : Int
  representative_is_default : Bool
  default_preservation_plan : OiChildLocalizationPlanFact
  non_default_localization_plan : OiChildLocalizationPlanFact
}

///|
priv struct OiArrayDefaultFallthroughFact {
  fallthrough_id : Int
}

///|
priv struct OiArrayDefaultPreservationFact {
  reached_fallthrough : Bool
  depth_exhausted : Bool
  local_tee_wrapper : Bool
  block_prefix_effectful : Bool
  nested_block_preserves : Bool
  loop_effectful : Bool
  if_control_shape : Bool
  subtree_effectful : Bool
}

///|
priv struct OiArrayDefaultValueFact {
  is_default : Bool
  preservation_plan : OiChildLocalizationPlanFact
}

///|
priv struct OiArrayStorageDefaultValueFact {
  is_default : Bool
}

///|
fn OiArrayStorageDefaultValueFact::from_value(
  func : @ir.HotFunc,
  storage : @lib.StorageType,
  value_id : Int,
) -> OiArrayStorageDefaultValueFact {
  // Binaryen's array default rewrites prove the fallthrough initializer equals
  // the field storage default before erasing or replacing allocation operands.
  // Keep the exact represented zero/null set as a reusable fact; broader SIMD
  // and nullable array constructor cases remain documented parser/HOT blockers.
  let value = @ir.hot_node_get(func, value_id)
  let is_default = match storage.unpack() {
    @lib.ValType::NumTypeValType(@lib.NumType::I32NumType) =>
      match value.op {
        @ir.HotOp::Const =>
          @ir.hot_const_get(func, value.imm0) ==
          @ir.HotConstPayload::i32_const(@lib.I32(0))
        _ => false
      }
    @lib.ValType::NumTypeValType(@lib.NumType::I64NumType) =>
      match value.op {
        @ir.HotOp::Const =>
          @ir.hot_const_get(func, value.imm0) ==
          @ir.HotConstPayload::i64_const(@lib.I64(0L))
        _ => false
      }
    @lib.ValType::NumTypeValType(@lib.NumType::F32NumType) =>
      match value.op {
        @ir.HotOp::Const =>
          @ir.hot_const_get(func, value.imm0) ==
          @ir.HotConstPayload::f32_const(@lib.F32(0.0))
        _ => false
      }
    @lib.ValType::NumTypeValType(@lib.NumType::F64NumType) =>
      match value.op {
        @ir.HotOp::Const =>
          @ir.hot_const_get(func, value.imm0) ==
          @ir.HotConstPayload::f64_const(@lib.F64(0.0))
        _ => false
      }
    @lib.ValType::RefTypeValType(ref_type) =>
      if !ref_type.is_nullable() {
        false
      } else {
        match value.op {
          @ir.HotOp::RefNull => true
          @ir.HotOp::Const =>
            match @ir.hot_const_get(func, value.imm0) {
              @ir.HotConstPayload::RefNullConst(_) => true
              _ => false
            }
          _ => false
        }
      }
    _ => false
  }
  { is_default, }
}

///|
fn OiArrayStorageDefaultValueFact::proves_default(
  self : OiArrayStorageDefaultValueFact,
) -> Bool {
  self.is_default
}

///|
fn OiArrayStorageDefaultValueFact::proves_value_default_for_storage(
  func : @ir.HotFunc,
  storage : @lib.StorageType,
  value_id : Int,
) -> Bool {
  OiArrayStorageDefaultValueFact::from_value(func, storage, value_id).proves_default()
}

///|
fn optimize_instructions_array_default_fallthrough_id(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  value_id : Int,
  depth? : Int = 0,
) -> Int {
  if depth > 8 {
    return value_id
  }
  let value = @ir.hot_node_get(func, value_id)
  match value.op {
    @ir.HotOp::LocalTee if value.child_count == 1 =>
      optimize_instructions_array_default_fallthrough_id(
        func,
        node_masks,
        @ir.hot_child_get(func, value_id, 0),
        depth=depth + 1,
      )
    @ir.HotOp::Block if value.child_count > 0 => {
      for slot = 0; slot < value.child_count - 1; slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, value_id, slot)
        if (node_masks[child_id] & @ir.EFFECT_MASK_CONTROL) != 0U {
          return value_id
        }
      }
      optimize_instructions_array_default_fallthrough_id(
        func,
        node_masks,
        @ir.hot_child_get(func, value_id, value.child_count - 1),
        depth=depth + 1,
      )
    }
    @ir.HotOp::Loop =>
      match
        optimize_instructions_region_tail_id(
          func,
          @ir.hot_region_body_ref(func, value_id),
        ) {
        Some(tail_id) =>
          optimize_instructions_array_default_fallthrough_id(
            func,
            node_masks,
            tail_id,
            depth=depth + 1,
          )
        None => value_id
      }
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, value_id) {
        Some(else_ref) => {
          let then_ref = @ir.hot_region_then_ref(func, value_id)
          let then_stops = optimize_instructions_region_explicitly_does_not_fallthrough(
            func, then_ref,
          )
          let else_stops = optimize_instructions_region_explicitly_does_not_fallthrough(
            func, else_ref,
          )
          let fallthrough_region = if then_stops && !else_stops {
            Some(else_ref)
          } else if else_stops && !then_stops {
            Some(then_ref)
          } else {
            None
          }
          match fallthrough_region {
            Some(region_ref) =>
              match optimize_instructions_region_tail_id(func, region_ref) {
                Some(tail_id) =>
                  optimize_instructions_array_default_fallthrough_id(
                    func,
                    node_masks,
                    tail_id,
                    depth=depth + 1,
                  )
                None => value_id
              }
            None => value_id
          }
        }
        None => value_id
      }
    _ => value_id
  }
}

///|
fn OiArrayDefaultPreservationFact::empty() -> OiArrayDefaultPreservationFact {
  {
    reached_fallthrough: false,
    depth_exhausted: false,
    local_tee_wrapper: false,
    block_prefix_effectful: false,
    nested_block_preserves: false,
    loop_effectful: false,
    if_control_shape: false,
    subtree_effectful: false,
  }
}

///|
fn OiArrayDefaultPreservationFact::from_value(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  value_id : Int,
  fallthrough_id : Int,
  depth? : Int = 0,
) -> OiArrayDefaultPreservationFact {
  // Binaryen v130 `getDroppedChildrenAndAppend` preserves only wrappers whose
  // evaluation can remain observable while replacing an array default value
  // with the canonical default initializer. Keep the represented Starshine
  // subset as an explicit preservation fact: matching fallthroughs and the
  // depth guard erase, local.tee and `if` wrappers preserve, blocks preserve if
  // any prefix child has effects or if the fallthrough child recursively needs
  // preservation, and loops/other subtrees preserve only when HOT effects are
  // not pure.
  if value_id == fallthrough_id {
    let fact = OiArrayDefaultPreservationFact::empty()
    return { ..fact, reached_fallthrough: true }
  }
  if depth > 8 {
    let fact = OiArrayDefaultPreservationFact::empty()
    return { ..fact, depth_exhausted: true }
  }
  let value = @ir.hot_node_get(func, value_id)
  match value.op {
    @ir.HotOp::LocalTee if value.child_count == 1 => {
      let fact = OiArrayDefaultPreservationFact::empty()
      { ..fact, local_tee_wrapper: true }
    }
    @ir.HotOp::Block if value.child_count > 0 => {
      let mut block_prefix_effectful = false
      for slot = 0; slot < value.child_count - 1; slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, value_id, slot)
        if !OiNodeEffectPurityFact::from_node_masks(node_masks, child_id).proves_pure() {
          block_prefix_effectful = true
        }
      }
      if block_prefix_effectful {
        let fact = OiArrayDefaultPreservationFact::empty()
        { ..fact, block_prefix_effectful: true }
      } else {
        let nested = OiArrayDefaultPreservationFact::from_value(
          func,
          node_masks,
          @ir.hot_child_get(func, value_id, value.child_count - 1),
          fallthrough_id,
          depth=depth + 1,
        )
        let fact = OiArrayDefaultPreservationFact::empty()
        { ..fact, nested_block_preserves: nested.proves_preserve_needed() }
      }
    }
    @ir.HotOp::Loop => {
      let fact = OiArrayDefaultPreservationFact::empty()
      {
        ..fact,
        loop_effectful: !OiNodeEffectPurityFact::from_node_masks(
          node_masks, value_id,
        ).proves_pure(),
      }
    }
    @ir.HotOp::If => {
      let fact = OiArrayDefaultPreservationFact::empty()
      { ..fact, if_control_shape: true }
    }
    _ => {
      let fact = OiArrayDefaultPreservationFact::empty()
      {
        ..fact,
        subtree_effectful: !OiNodeEffectPurityFact::from_node_masks(
          node_masks, value_id,
        ).proves_pure(),
      }
    }
  }
}

///|
fn OiArrayDefaultPreservationFact::proves_preserve_needed(
  self : OiArrayDefaultPreservationFact,
) -> Bool {
  ignore(self.reached_fallthrough)
  ignore(self.depth_exhausted)
  self.local_tee_wrapper ||
  self.block_prefix_effectful ||
  self.nested_block_preserves ||
  self.loop_effectful ||
  self.if_control_shape ||
  self.subtree_effectful
}

///|
fn OiArrayDefaultFallthroughFact::from_value(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  value_id : Int,
) -> OiArrayDefaultFallthroughFact {
  let fallthrough_id = optimize_instructions_array_default_fallthrough_id(
    func, node_masks, value_id,
  )
  { fallthrough_id, }
}

///|
fn OiChildLocalizationPlanFact::empty() -> OiChildLocalizationPlanFact {
  { source_ids: [], drop_ids: [] }
}

///|
fn OiChildLocalizationPlanFact::from_repeated_array_new_fixed_non_default(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiChildLocalizationPlanFact {
  // Binaryen v130 `visitArrayNewFixed` hands the non-default repeated-value
  // rewrite to `ChildLocalizer`: operands whose evaluation must remain visible
  // are materialized before the replacement `array.new`, while trivially pure
  // duplicate scalars are dropped. Represent that decision as a reusable plan
  // fact instead of storing an ad hoc list on the array constructor fact.
  let effects = pass_require_effects(ctx, func)
  let node = @ir.hot_node_get(func, node_id)
  let source_ids : Array[Int] = []
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if !OiNodeEffectPurityFact::from_node_masks(effects.node_masks, child_id).proves_pure() {
      source_ids.push(child_id)
    }
  }
  { source_ids, drop_ids: [] }
}

///|
fn OiChildLocalizationPlanFact::needs_localization(
  self : OiChildLocalizationPlanFact,
) -> Bool {
  self.source_ids.length() > 0
}

///|
fn OiChildLocalizationPlanFact::from_array_default_fallthrough(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  value_id : Int,
  fallthrough_id : Int,
) -> OiChildLocalizationPlanFact {
  // Binaryen v130 uses `getDroppedChildrenAndAppend` for both `array.new`
  // default-initializer rewrites and default repeated `array.new_fixed`
  // rewrites. Represent the dropped-child preservation decision as the same
  // ChildLocalizer-shaped fact used by non-default repeated fixed arrays: pure
  // default-producing wrappers are erased, while value wrappers with observable
  // effects are explicitly dropped before the replacement allocation.
  if OiArrayDefaultPreservationFact::from_value(
      func, node_masks, value_id, fallthrough_id,
    ).proves_preserve_needed() {
    { source_ids: [], drop_ids: [value_id] }
  } else {
    OiChildLocalizationPlanFact::empty()
  }
}

///|
fn OiChildLocalizationPlanFact::from_array_new_default_initializer(
  value_id : Int,
) -> OiChildLocalizationPlanFact {
  // Binaryen v130 `visitArrayNew` always sequences `drop(init)` before the
  // converted `array.new_default`, even when the fallthrough default itself is
  // pure. Keep that separate from the fixed-array default plan, where
  // `getDroppedChildrenAndAppend` can erase pure duplicate default operands.
  { source_ids: [], drop_ids: [value_id] }
}

///|
fn OiChildLocalizationPlanFact::needs_dropped_children(
  self : OiChildLocalizationPlanFact,
) -> Bool {
  self.drop_ids.length() > 0
}

///|
fn OiChildLocalizationPlanFact::append_dropped_children(
  self : OiChildLocalizationPlanFact,
  func : @ir.HotFunc,
  body : Array[Int],
) -> Unit {
  for source_id in self.drop_ids {
    body.push(@ir.hot_build_drop(func, source_id))
  }
}

///|
fn OiChildLocalizationPlanFact::append_localized_inputs(
  self : OiChildLocalizationPlanFact,
  func : @ir.HotFunc,
  value_type : @lib.ValType,
  representative_id : Int,
  body : Array[Int],
) -> Int {
  let mut representative_local = -1
  for source_id in self.source_ids {
    let local_id = optimize_instructions_add_temp_local(func, value_type)
    if source_id == representative_id && representative_local < 0 {
      representative_local = local_id
    }
    body.push(@ir.hot_build_local_set(func, local_id, source_id))
  }
  if representative_local >= 0 {
    @ir.hot_build_local_get(func, representative_local)
  } else {
    representative_id
  }
}

///|
fn OiArrayDefaultValueFact::from_array_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  type_idx : @lib.TypeIdx,
  value_id : Int,
) -> OiArrayDefaultValueFact {
  // Binaryen v130 `visitArrayNew` and `visitArrayNewFixed` check
  // `getFallthrough(value)` before deciding whether an array initializer or an
  // equal fixed-array representative is the storage default, then delegate
  // effect preservation to `getDroppedChildrenAndAppend`. Keep the represented
  // fallthrough/default result as a fact so constructor rewrites do not inline a
  // one-off local.tee, block, loop, or one-unreachable-arm `if` scanner. Broader
  // Binaryen `getFallthrough` shapes stay documented until they have
  // source-probed preservation facts.
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None =>
      return {
        is_default: false,
        preservation_plan: OiChildLocalizationPlanFact::empty(),
      }
  }
  let field = match @ir.hot_module_resolve_array_field(module_ctx, type_idx) {
    Some(field) => field
    None =>
      return {
        is_default: false,
        preservation_plan: OiChildLocalizationPlanFact::empty(),
      }
  }
  let effects = pass_require_effects(ctx, func)
  let fallthrough_fact = OiArrayDefaultFallthroughFact::from_value(
    func,
    effects.node_masks,
    value_id,
  )
  if !OiArrayStorageDefaultValueFact::proves_value_default_for_storage(
      func,
      field.get_storage_type(),
      fallthrough_fact.fallthrough_id,
    ) {
    return {
      is_default: false,
      preservation_plan: OiChildLocalizationPlanFact::empty(),
    }
  }
  {
    is_default: true,
    preservation_plan: OiChildLocalizationPlanFact::from_array_default_fallthrough(
      func,
      effects.node_masks,
      value_id,
      fallthrough_fact.fallthrough_id,
    ),
  }
}

///|
fn OiArrayNewFixedRepeatedValueFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiArrayNewFixedRepeatedValueFact? {
  let node = @ir.hot_node_get(func, node_id)
  let (type_idx, size) = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayNewFixed(type_idx, @lib.U32(size))) =>
      (type_idx, size.reinterpret_as_int())
    _ => return None
  }
  if size <= 0 || size != node.child_count {
    return None
  }
  for slot = 0; slot < node.child_count - 1; slot = slot + 1 {
    let equality_fact = OiConsecutiveInputEqualityFact::from_adjacent_operands(
      ctx,
      func,
      @ir.hot_child_get(func, node_id, slot),
      @ir.hot_child_get(func, node_id, slot + 1),
    )
    if !equality_fact.proves_equal(func) {
      return None
    }
  }
  let representative_id = @ir.hot_child_get(func, node_id, 0)
  let default_fact = OiArrayDefaultValueFact::from_array_value(
    ctx, func, type_idx, representative_id,
  )
  let non_default_localization_plan = if default_fact.is_default {
    OiChildLocalizationPlanFact::empty()
  } else {
    OiChildLocalizationPlanFact::from_repeated_array_new_fixed_non_default(
      ctx, func, node_id,
    )
  }
  Some({
    node_id,
    type_idx,
    size,
    representative_id,
    representative_is_default: default_fact.is_default,
    default_preservation_plan: default_fact.preservation_plan,
    non_default_localization_plan,
  })
}

///|
fn OiArrayNewFixedRepeatedValueFact::is_rewritable(
  self : OiArrayNewFixedRepeatedValueFact,
) -> Bool {
  self.representative_is_default || self.size >= 2
}

///|
fn OiArrayNewFixedRepeatedValueFact::apply_non_default_localized_rewrite(
  self : OiArrayNewFixedRepeatedValueFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  // Binaryen v130 routes the non-default `array.new_fixed` -> `array.new`
  // collapse through `getDroppedChildrenAndAppend`, which materializes
  // state-reading/effectful fixed operands into scratch locals before the new
  // repeated-value allocation. Keep that preservation as data on the repeated
  // value fact instead of letting the rewrite drop every non-representative
  // operand after equality succeeds.
  let value_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, self.representative_id)) {
    [value_type] => value_type
    _ => return false
  }
  let original = @ir.hot_node_get(func, self.node_id)
  let body : Array[Int] = []
  let representative_value_id = self.non_default_localization_plan.append_localized_inputs(
    func,
    value_type,
    self.representative_id,
    body,
  )
  let len_id = @ir.hot_build_const_i32(func, @lib.I32(self.size))
  let temp = @ir.hot_build_node(
    func,
    original.op,
    @ir.hot_node_type(func, self.node_id),
    children=[representative_value_id, len_id],
  )
  @ir.hot_node_exact_instr_set(
    func,
    temp,
    @lib.Instruction::array_new(self.type_idx),
  )
  body.push(temp)
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, self.node_id)) {
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => @lib.BlockType::void_()
  }
  let replacement_id = @ir.hot_build_block(func, block_type, body)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_replace_node(func, self.node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, self.node_id),
    self.node_id,
  )
  @ir.hot_delete_node(func, replacement_id)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn OiArrayNewFixedRepeatedValueFact::apply_rewrite(
  self : OiArrayNewFixedRepeatedValueFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  if !self.representative_is_default &&
    self.non_default_localization_plan.needs_localization() &&
    self.apply_non_default_localized_rewrite(ctx, func) {
    return
  }
  let original = @ir.hot_node_get(func, self.node_id)
  let len_id = @ir.hot_build_const_i32(func, @lib.I32(self.size))
  let temp = if self.representative_is_default {
    @ir.hot_build_node(
      func,
      original.op,
      @ir.hot_node_type(func, self.node_id),
      children=[len_id],
    )
  } else {
    @ir.hot_build_node(
      func,
      original.op,
      @ir.hot_node_type(func, self.node_id),
      children=[self.representative_id, len_id],
    )
  }
  @ir.hot_node_exact_instr_set(
    func,
    temp,
    if self.representative_is_default {
      @lib.Instruction::array_new_default(self.type_idx)
    } else {
      @lib.Instruction::array_new(self.type_idx)
    },
  )
  if self.representative_is_default &&
    self.default_preservation_plan.needs_dropped_children() {
    let block_type = match
      @ir.hot_type_results(func, @ir.hot_node_type(func, self.node_id)) {
      [val_type] => @lib.BlockType::val_type(val_type)
      _ => @lib.BlockType::void_()
    }
    let body : Array[Int] = []
    self.default_preservation_plan.append_dropped_children(func, body)
    body.push(temp)
    let replacement_id = @ir.hot_build_block(func, block_type, body)
    let replacement = @ir.hot_node_get(func, replacement_id)
    @ir.hot_replace_node(func, self.node_id, replacement)
    @ir.hot_label_owner_set(
      func,
      @ir.hot_control_node_label(func, self.node_id),
      self.node_id,
    )
    @ir.hot_delete_node(func, replacement_id)
  } else {
    let replacement = @ir.hot_node_get(func, temp)
    @ir.hot_delete_node(func, temp)
    @ir.hot_replace_node(func, self.node_id, replacement)
  }
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_try_rewrite_array_new_fixed_repeated_values(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let fact = match
    OiArrayNewFixedRepeatedValueFact::from_node(ctx, func, node_id) {
    Some(fact) => fact
    None => return false
  }
  if !fact.is_rewritable() {
    return false
  }
  fact.apply_rewrite(ctx, func)
  true
}

///|
priv struct OiArrayNewDefaultInitRewriteFact {
  node_id : Int
  type_idx : @lib.TypeIdx
  preservation_plan : OiChildLocalizationPlanFact
  len_id : Int
}

///|
priv struct OiArrayNewSingleFixedFact {
  node_id : Int
  type_idx : @lib.TypeIdx
  init_id : Int
}

///|
fn OiArrayNewDefaultInitRewriteFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiArrayNewDefaultInitRewriteFact? {
  let node = @ir.hot_node_get(func, node_id)
  let type_idx = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayNew(type_idx)) => type_idx
    _ => return None
  }
  if node.child_count != 2 {
    return None
  }
  let init_id = @ir.hot_child_get(func, node_id, 0)
  let default_fact = OiArrayDefaultValueFact::from_array_value(
    ctx, func, type_idx, init_id,
  )
  if !default_fact.is_default {
    return None
  }
  Some({
    node_id,
    type_idx,
    preservation_plan: OiChildLocalizationPlanFact::from_array_new_default_initializer(
      init_id,
    ),
    len_id: @ir.hot_child_get(func, node_id, 1),
  })
}

///|
fn OiArrayNewDefaultInitRewriteFact::apply_rewrite(
  self : OiArrayNewDefaultInitRewriteFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  let original = @ir.hot_node_get(func, self.node_id)
  let temp = @ir.hot_build_node(
    func,
    original.op,
    @ir.hot_node_type(func, self.node_id),
    children=[self.len_id],
  )
  @ir.hot_node_exact_instr_set(
    func,
    temp,
    @lib.Instruction::array_new_default(self.type_idx),
  )
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, self.node_id)) {
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => @lib.BlockType::void_()
  }
  let body : Array[Int] = []
  self.preservation_plan.append_dropped_children(func, body)
  body.push(temp)
  let replacement_id = @ir.hot_build_block(func, block_type, body)
  let replacement = @ir.hot_node_get(func, replacement_id)
  @ir.hot_replace_node(func, self.node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, self.node_id),
    self.node_id,
  )
  @ir.hot_delete_node(func, replacement_id)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_try_rewrite_array_new_default_init(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let fact = match
    OiArrayNewDefaultInitRewriteFact::from_node(ctx, func, node_id) {
    Some(fact) => fact
    None => return false
  }
  fact.apply_rewrite(ctx, func)
  true
}

///|
fn OiArrayNewSingleFixedFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiArrayNewSingleFixedFact? {
  let node = @ir.hot_node_get(func, node_id)
  let type_idx = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayNew(type_idx)) => type_idx
    _ => return None
  }
  if node.child_count != 2 {
    return None
  }
  let len_id = @ir.hot_child_get(func, node_id, 1)
  match @ir.hot_node_get(func, len_id).op {
    @ir.HotOp::Const =>
      if @ir.hot_const_get(func, @ir.hot_node_get(func, len_id).imm0) !=
        @ir.HotConstPayload::i32_const(@lib.I32(1)) {
        return None
      }
    _ => return None
  }
  Some({ node_id, type_idx, init_id: @ir.hot_child_get(func, node_id, 0) })
}

///|
fn OiArrayNewSingleFixedFact::apply_rewrite(
  self : OiArrayNewSingleFixedFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  let original = @ir.hot_node_get(func, self.node_id)
  let temp = @ir.hot_build_node(
    func,
    original.op,
    @ir.hot_node_type(func, self.node_id),
    children=[self.init_id],
  )
  @ir.hot_node_exact_instr_set(
    func,
    temp,
    @lib.Instruction::array_new_fixed(self.type_idx, @lib.U32(1U)),
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, self.node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_try_rewrite_array_new_single_fixed(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let fact = match OiArrayNewSingleFixedFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return false
  }
  fact.apply_rewrite(ctx, func)
  true
}

///|
fn optimize_instructions_try_fold_array_len_new_fixed(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayLen) => ()
    _ => return false
  }
  let array_id = @ir.hot_child_get(func, node_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, array_id) ||
    pass_node_use_count(ctx, func, array_id) != 1 {
    return false
  }
  let array_node = @ir.hot_node_get(func, array_id)
  let len = match @ir.hot_node_exact_instr(func, array_id) {
    Some(@lib.Instruction::ArrayNewFixed(_, @lib.U32(len))) => {
      let len = len.reinterpret_as_int()
      if len != array_node.child_count {
        return false
      }
      for i = 0; i < array_node.child_count; i = i + 1 {
        if !optimize_instructions_node_effects_are_pure(
            ctx,
            func,
            @ir.hot_child_get(func, array_id, i),
          ) {
          return false
        }
      }
      len
    }
    Some(@lib.Instruction::ArrayNewDefault(_)) => {
      if array_node.child_count != 1 {
        return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        Some(@lib.I32(len)) if OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      len
    }
    Some(@lib.Instruction::ArrayNew(_)) => {
      if array_node.child_count != 2 {
        return false
      }
      let repeated_value_id = @ir.hot_child_get(func, array_id, 0)
      let len_id = @ir.hot_child_get(func, array_id, 1)
      let len = match optimize_instructions_i32_const(func, dead, len_id) {
        Some(@lib.I32(len)) if OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      match optimize_instructions_i32_const(func, dead, repeated_value_id) {
        Some(_) => len
        None => {
          if OiTriviallyPureOperandFact::proves_node_pure(
              func, repeated_value_id,
            ) ||
            optimize_instructions_node_effects_are_pure(
              ctx, func, repeated_value_id,
            ) {
            return false
          }
          return optimize_instructions_try_replace_with_ordered_effects_then_const_i32(
            ctx,
            func,
            node_id,
            [repeated_value_id, len_id],
            @lib.I32(len),
          )
        }
      }
    }
    _ => return false
  }
  optimize_instructions_replace_with_const_i32(
    ctx,
    func,
    node_id,
    @lib.I32(len),
  )
  true
}

///|
fn optimize_instructions_try_fold_array_get_new_fixed(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return false
  }
  let (type_idx, packed_signed) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArrayGet(type_idx)) => (type_idx, None)
    Some(@lib.Instruction::ArrayGetS(type_idx)) => (type_idx, Some(true))
    Some(@lib.Instruction::ArrayGetU(type_idx)) => (type_idx, Some(false))
    _ => return false
  }
  let array_id = @ir.hot_child_get(func, node_id, 0)
  let index_id = @ir.hot_child_get(func, node_id, 1)
  if !OiLiveNodeFact::proves_node_live(func, dead, array_id) ||
    pass_node_use_count(ctx, func, array_id) != 1 {
    return false
  }
  let index = match optimize_instructions_i32_const(func, dead, index_id) {
    Some(@lib.I32(index)) => index
    _ => return false
  }
  let array_node = @ir.hot_node_get(func, array_id)
  // 0 = array.new_fixed, 1 = array.new_default, 2 = array.new repeated value.
  let (array_kind, len) = match @ir.hot_node_exact_instr(func, array_id) {
    Some(@lib.Instruction::ArrayNewFixed(new_type_idx, @lib.U32(len))) if new_type_idx ==
      type_idx => {
      let len = len.reinterpret_as_int()
      if len != array_node.child_count {
        return false
      }
      (0, len)
    }
    Some(@lib.Instruction::ArrayNewDefault(new_type_idx)) if new_type_idx ==
      type_idx => {
      if array_node.child_count != 1 {
        return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 0),
        ) {
        Some(@lib.I32(len)) if OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      (1, len)
    }
    Some(@lib.Instruction::ArrayNew(new_type_idx)) if new_type_idx == type_idx => {
      if array_node.child_count != 2 {
        return false
      }
      let len = match
        optimize_instructions_i32_const(
          func,
          dead,
          @ir.hot_child_get(func, array_id, 1),
        ) {
        Some(@lib.I32(len)) if OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      (2, len)
    }
    _ => return false
  }
  if array_kind == 2 {
    let repeated_value_id = @ir.hot_child_get(func, array_id, 0)
    if !OiOrderedOperandFact::from_node(ctx, func, repeated_value_id).can_preserve_scalar_selected_value() {
      return false
    }
  }
  if array_kind == 0 {
    if index >= 0 && index < len && packed_signed == None {
      let operands : Array[Int] = []
      for i = 0; i < array_node.child_count; i = i + 1 {
        operands.push(@ir.hot_child_get(func, array_id, i))
      }
      return optimize_instructions_try_forward_selected_operand_preserving_effects(
        ctx, func, node_id, operands, index,
      )
    }
    for i = 0; i < array_node.child_count; i = i + 1 {
      if (index < 0 || index >= len || i != index) &&
        !optimize_instructions_node_effects_are_pure(
          ctx,
          func,
          @ir.hot_child_get(func, array_id, i),
        ) {
        return false
      }
    }
  }
  if index < 0 || index >= len {
    if array_kind == 2 {
      return optimize_instructions_try_replace_with_ordered_effects_then_unreachable(
        ctx,
        func,
        node_id,
        [
          @ir.hot_child_get(func, array_id, 0),
          @ir.hot_child_get(func, array_id, 1),
          index_id,
        ],
      )
    }
    if !optimize_instructions_node_effects_are_pure(ctx, func, index_id) {
      return false
    }
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
  } else {
    let value_id = if array_kind == 0 {
      @ir.hot_child_get(func, array_id, index)
    } else if array_kind == 1 {
      match
        optimize_instructions_array_default_element_value(ctx, func, type_idx) {
        Some(value_id) => value_id
        None => return false
      }
    } else {
      @ir.hot_child_get(func, array_id, 0)
    }
    match packed_signed {
      Some(signed) => {
        let bits = match
          optimize_instructions_array_field_pack_bits(ctx, type_idx) {
          Some(bits) => bits
          None => return false
        }
        optimize_instructions_replace_with_packed_i32_value(
          ctx, func, dead, node_id, value_id, bits, signed,
        )
      }
      None =>
        optimize_instructions_replace_with_node_id(ctx, func, node_id, value_id)
    }
  }
  true
}

///|
fn optimize_instructions_replace_with_nop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Unit {
  let temp = @ir.hot_build_nop(func)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_try_remove_array_set_fresh_array(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 3 {
    return false
  }
  let type_idx = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::ArraySet(type_idx)) => type_idx
    _ => return false
  }
  let array_id = @ir.hot_child_get(func, node_id, 0)
  let index_id = @ir.hot_child_get(func, node_id, 1)
  let value_id = @ir.hot_child_get(func, node_id, 2)
  if !OiLiveNodeFact::proves_node_live(func, dead, array_id) ||
    pass_node_use_count(ctx, func, array_id) != 1 {
    return false
  }
  let index = match optimize_instructions_i32_const(func, dead, index_id) {
    Some(@lib.I32(index)) => index
    _ => return false
  }
  let array_node = @ir.hot_node_get(func, array_id)
  let effect_operands : Array[Int] = []
  let len = match @ir.hot_node_exact_instr(func, array_id) {
    Some(@lib.Instruction::ArrayNewFixed(new_type_idx, @lib.U32(len))) if new_type_idx ==
      type_idx => {
      let len = len.reinterpret_as_int()
      if len != array_node.child_count {
        return false
      }
      for i = 0; i < array_node.child_count; i = i + 1 {
        effect_operands.push(@ir.hot_child_get(func, array_id, i))
      }
      len
    }
    Some(@lib.Instruction::ArrayNewDefault(new_type_idx)) if new_type_idx ==
      type_idx => {
      if array_node.child_count != 1 {
        return false
      }
      let len_id = @ir.hot_child_get(func, array_id, 0)
      effect_operands.push(len_id)
      match optimize_instructions_i32_const(func, dead, len_id) {
        Some(@lib.I32(len)) if OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
    }
    Some(@lib.Instruction::ArrayNew(new_type_idx)) if new_type_idx == type_idx => {
      if array_node.child_count != 2 {
        return false
      }
      let repeated_value_id = @ir.hot_child_get(func, array_id, 0)
      let len_id = @ir.hot_child_get(func, array_id, 1)
      effect_operands.push(repeated_value_id)
      effect_operands.push(len_id)
      match optimize_instructions_i32_const(func, dead, len_id) {
        Some(@lib.I32(len)) if OiArrayNonTrappingLengthFact::proves_len_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
    }
    _ => return false
  }
  effect_operands.push(index_id)
  effect_operands.push(value_id)
  optimize_instructions_try_replace_with_ordered_effects_then_void(
    ctx,
    func,
    node_id,
    effect_operands,
    index < 0 || index >= len,
  )
}

///|
fn optimize_instructions_try_fold_struct_get_struct_new(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 1 {
    return false
  }
  let (type_idx, field_idx, packed_signed) = match
    @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructGet(type_idx, @lib.U32(field_idx))) =>
      (type_idx, field_idx.reinterpret_as_int(), None)
    Some(@lib.Instruction::StructGetS(type_idx, @lib.U32(field_idx))) =>
      (type_idx, field_idx.reinterpret_as_int(), Some(true))
    Some(@lib.Instruction::StructGetU(type_idx, @lib.U32(field_idx))) =>
      (type_idx, field_idx.reinterpret_as_int(), Some(false))
    _ => return false
  }
  let struct_id = @ir.hot_child_get(func, node_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, struct_id) ||
    pass_node_use_count(ctx, func, struct_id) != 1 {
    return false
  }
  let struct_node = @ir.hot_node_get(func, struct_id)
  let value_id = match @ir.hot_node_exact_instr(func, struct_id) {
    Some(@lib.Instruction::StructNew(new_type_idx)) if new_type_idx == type_idx => {
      if field_idx < 0 || field_idx >= struct_node.child_count {
        return false
      }
      if packed_signed == None {
        let operands : Array[Int] = []
        for i = 0; i < struct_node.child_count; i = i + 1 {
          operands.push(@ir.hot_child_get(func, struct_id, i))
        }
        return optimize_instructions_try_forward_selected_operand_preserving_effects(
          ctx, func, node_id, operands, field_idx,
        )
      }
      for i = 0; i < struct_node.child_count; i = i + 1 {
        if i != field_idx &&
          !optimize_instructions_node_effects_are_pure(
            ctx,
            func,
            @ir.hot_child_get(func, struct_id, i),
          ) {
          return false
        }
      }
      @ir.hot_child_get(func, struct_id, field_idx)
    }
    Some(@lib.Instruction::StructNewDefault(new_type_idx)) if new_type_idx ==
      type_idx =>
      match
        optimize_instructions_struct_default_field_value(
          ctx, func, type_idx, field_idx,
        ) {
        Some(value_id) => value_id
        None => return false
      }
    _ => return false
  }
  match packed_signed {
    Some(signed) => {
      let bits = match
        optimize_instructions_struct_field_pack_bits(ctx, type_idx, field_idx) {
        Some(bits) => bits
        None => return false
      }
      optimize_instructions_replace_with_packed_i32_value(
        ctx, func, dead, node_id, value_id, bits, signed,
      )
    }
    None =>
      optimize_instructions_replace_with_node_id(ctx, func, node_id, value_id)
  }
  true
}

///|
fn optimize_instructions_try_truncate_narrow_store_const_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match
    OiStoredValueRewritePlanFact::from_truncated_const(func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_drop_narrow_store_value_mask(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiStoredValueRewritePlanFact::from_low_bit_mask(func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_rewrite_reinterpret_store_value(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiStoredValueRewritePlanFact::from_reinterpret(func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_rewrite_reinterpret_load_result(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match
    OiLoadResultRewritePlanFact::from_reinterpret(ctx, func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_rewrite_i64_extend_i32_load_result(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match
    OiLoadResultRewritePlanFact::from_i64_extend_i32(ctx, func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_widen_store_of_wrap_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match
    OiStoredValueRewritePlanFact::from_wrap_i64_widen(ctx, func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_replace_with_dropped_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operands : Array[Int],
) -> Unit {
  let body : Array[Int] = []
  for operand in operands {
    body.push(@ir.hot_build_drop(func, operand))
  }
  let temp = @ir.hot_build_block(func, @lib.BlockType::void_(), body)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
}

///|
priv enum OiBulkMemoryRewritePlanKind {
  BulkMemoryDropSameAddressCopy
  BulkMemoryDropZeroSizeCopy
  BulkMemoryDropZeroSizeFill
  BulkMemoryTinyCopy
  BulkMemoryTinyFill
}

///|
priv struct OiBulkMemoryRewritePlanFact {
  kind : OiBulkMemoryRewritePlanKind
  bulk_fact : OiBulkMemoryFact
  copy_fact : OiTinyMemoryCopyFact?
  fill_fact : OiTinyMemoryFillFact?
}

///|
fn OiBulkMemoryRewritePlanFact::from_copy(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiBulkMemoryRewritePlanFact? {
  // Binaryen v130 `optimizeMemoryCopy` first handles trap-relaxed identical
  // addresses, then trap-relaxed zero sizes, then constant tiny load/store
  // lowering. Keep that source order as a plan fact so the visitor does not own
  // a branch cascade for the OI-G bulk-memory rewrite families.
  let bulk_fact = match OiBulkMemoryFact::from_copy(func, dead, node_id) {
    Some(fact) => fact
    None => return None
  }
  if bulk_fact.can_drop_same_address_copy_trap_relaxed(ctx, func) {
    return Some({
      kind: BulkMemoryDropSameAddressCopy,
      bulk_fact,
      copy_fact: None,
      fill_fact: None,
    })
  }
  if bulk_fact.can_drop_zero_size_trap_relaxed(ctx, func) {
    return Some({
      kind: BulkMemoryDropZeroSizeCopy,
      bulk_fact,
      copy_fact: None,
      fill_fact: None,
    })
  }
  if !bulk_fact.has_const_size_operand() {
    return None
  }
  let copy_fact = match OiTinyMemoryCopyFact::from_size(ctx, bulk_fact.size) {
    Some(fact) => fact
    None => return None
  }
  Some({
    kind: BulkMemoryTinyCopy,
    bulk_fact,
    copy_fact: Some(copy_fact),
    fill_fact: None,
  })
}

///|
fn OiBulkMemoryRewritePlanFact::from_fill(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiBulkMemoryRewritePlanFact? {
  // Binaryen v130 `optimizeMemoryFill` requires a constant size, handles the
  // trap-relaxed zero-size drop, then lowers constant-byte fills and the
  // nonconstant size-1 store8 case. The feature-dependent no-SIMD size-16 i64
  // fallback stays outside this plan until Starshine has module-feature facts.
  let bulk_fact = match OiBulkMemoryFact::from_fill(func, dead, node_id) {
    Some(fact) => fact
    None => return None
  }
  if bulk_fact.can_drop_zero_size_trap_relaxed(ctx, func) {
    return Some({
      kind: BulkMemoryDropZeroSizeFill,
      bulk_fact,
      copy_fact: None,
      fill_fact: None,
    })
  }
  if !bulk_fact.has_const_size_operand() {
    return None
  }
  let fill_fact = match
    OiTinyMemoryFillFact::from_size_and_value(
      ctx,
      func,
      dead,
      bulk_fact.size,
      bulk_fact.src_or_value_id,
    ) {
    Some(fact) => fact
    None => return None
  }
  Some({
    kind: BulkMemoryTinyFill,
    bulk_fact,
    copy_fact: None,
    fill_fact: Some(fill_fact),
  })
}

///|
fn OiBulkMemoryRewritePlanFact::apply(
  self : OiBulkMemoryRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match self.kind {
    BulkMemoryDropSameAddressCopy => {
      optimize_instructions_replace_with_dropped_operands(ctx, func, node_id, [
        self.bulk_fact.dst_id,
        self.bulk_fact.src_or_value_id,
        self.bulk_fact.size_id,
      ])
      true
    }
    BulkMemoryDropZeroSizeCopy | BulkMemoryDropZeroSizeFill => {
      optimize_instructions_replace_with_dropped_operands(ctx, func, node_id, [
        self.bulk_fact.dst_id,
        self.bulk_fact.src_or_value_id,
      ])
      true
    }
    BulkMemoryTinyCopy => self.apply_tiny_copy(ctx, func, node_id)
    BulkMemoryTinyFill => self.apply_tiny_fill(ctx, func, node_id)
  }
}

///|
fn OiBulkMemoryRewritePlanFact::apply_tiny_copy(
  self : OiBulkMemoryRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let copy_fact = match self.copy_fact {
    Some(fact) => fact
    None => return false
  }
  let src_memarg = self.bulk_fact.src_memarg()
  let load = @ir.hot_build_load(
    func,
    copy_fact.load_type(),
    src_memarg,
    self.bulk_fact.src_or_value_id,
  )
  @ir.hot_node_exact_instr_set(func, load, copy_fact.load_instr(src_memarg))
  let dst_memarg = self.bulk_fact.dst_memarg()
  let temp = @ir.hot_build_store(func, dst_memarg, self.bulk_fact.dst_id, load)
  @ir.hot_node_exact_instr_set(func, temp, copy_fact.store_instr(dst_memarg))
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn OiBulkMemoryRewritePlanFact::apply_tiny_fill(
  self : OiBulkMemoryRewritePlanFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let fill_fact = match self.fill_fact {
    Some(fact) => fact
    None => return false
  }
  let stored_id = match
    fill_fact.build_store_value(func, self.bulk_fact.src_or_value_id) {
    Some(stored_id) => stored_id
    None => return false
  }
  optimize_instructions_replace_with_store_exact(
    ctx,
    func,
    node_id,
    self.bulk_fact.dst_mem_idx,
    self.bulk_fact.dst_id,
    stored_id,
    fn(memarg) { fill_fact.store_instr(memarg) },
  )
  true
}

///|
fn optimize_instructions_try_expand_tiny_memory_copy(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiBulkMemoryRewritePlanFact::from_copy(ctx, func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_expand_tiny_memory_fill(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiBulkMemoryRewritePlanFact::from_fill(ctx, func, dead, node_id) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
priv struct OiOrderedBinaryLocalLocalEqualityFact {
  instr : @lib.Instruction?
  matching_ordered_local_operands : Bool
}

///|
fn OiOrderedBinaryLocalLocalEqualityFact::from_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> OiOrderedBinaryLocalLocalEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` treats equal binary nodes as the
  // same operation with recursively equal ordered operands. For the select-arm
  // `!condition.invalidates(value)` path, this Starshine fact records the
  // represented nontrapping subset whose operands are direct locals and can be
  // re-evaluated after an effectful condition without reading mutable state.
  let mut instr : @lib.Instruction? = None
  let mut matching_ordered_local_operands = false
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) if lhs_instr == rhs_instr => {
      instr = Some(lhs_instr)
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      match
        (
          OiLocalGetLeafFact::from_node(func, dead, lhs_left).local_id,
          OiLocalGetLeafFact::from_node(func, dead, rhs_left).local_id,
          OiLocalGetLeafFact::from_node(func, dead, lhs_right).local_id,
          OiLocalGetLeafFact::from_node(func, dead, rhs_right).local_id,
        ) {
        (
          Some(lhs_left_local),
          Some(rhs_left_local),
          Some(lhs_right_local),
          Some(rhs_right_local),
        ) =>
          matching_ordered_local_operands = lhs_left_local == rhs_left_local &&
            lhs_right_local == rhs_right_local
        _ => ()
      }
    }
    _ => ()
  }
  { instr, matching_ordered_local_operands }
}

///|
fn OiOrderedBinaryLocalLocalEqualityFact::proves_instr(
  self : OiOrderedBinaryLocalLocalEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  if !self.matching_ordered_local_operands {
    return false
  }
  match self.instr {
    Some(actual) => actual == instr
    None => false
  }
}

///|
fn OiOrderedBinaryLocalLocalEqualityFact::proves_i32_nontrapping_scalar(
  self : OiOrderedBinaryLocalLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::i32_add()) ||
  self.proves_instr(@lib.Instruction::i32_sub()) ||
  self.proves_instr(@lib.Instruction::i32_mul()) ||
  self.proves_instr(@lib.Instruction::i32_and()) ||
  self.proves_instr(@lib.Instruction::i32_or()) ||
  self.proves_instr(@lib.Instruction::i32_xor()) ||
  self.proves_instr(@lib.Instruction::i32_shl()) ||
  self.proves_instr(@lib.Instruction::i32_shr_s()) ||
  self.proves_instr(@lib.Instruction::i32_shr_u()) ||
  self.proves_instr(@lib.Instruction::i32_rotl()) ||
  self.proves_instr(@lib.Instruction::i32_rotr()) ||
  self.proves_instr(@lib.Instruction::i32_eq()) ||
  self.proves_instr(@lib.Instruction::i32_ne()) ||
  self.proves_instr(@lib.Instruction::i32_lt_s()) ||
  self.proves_instr(@lib.Instruction::i32_lt_u()) ||
  self.proves_instr(@lib.Instruction::i32_gt_s()) ||
  self.proves_instr(@lib.Instruction::i32_gt_u()) ||
  self.proves_instr(@lib.Instruction::i32_le_s()) ||
  self.proves_instr(@lib.Instruction::i32_le_u()) ||
  self.proves_instr(@lib.Instruction::i32_ge_s()) ||
  self.proves_instr(@lib.Instruction::i32_ge_u())
}

///|
fn OiOrderedBinaryLocalLocalEqualityFact::proves_i64_nontrapping_scalar(
  self : OiOrderedBinaryLocalLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::i64_add()) ||
  self.proves_instr(@lib.Instruction::i64_sub()) ||
  self.proves_instr(@lib.Instruction::i64_mul()) ||
  self.proves_instr(@lib.Instruction::i64_and()) ||
  self.proves_instr(@lib.Instruction::i64_or()) ||
  self.proves_instr(@lib.Instruction::i64_xor()) ||
  self.proves_instr(@lib.Instruction::i64_shl()) ||
  self.proves_instr(@lib.Instruction::i64_shr_s()) ||
  self.proves_instr(@lib.Instruction::i64_shr_u()) ||
  self.proves_instr(@lib.Instruction::i64_rotl()) ||
  self.proves_instr(@lib.Instruction::i64_rotr()) ||
  self.proves_instr(@lib.Instruction::i64_eq()) ||
  self.proves_instr(@lib.Instruction::i64_ne()) ||
  self.proves_instr(@lib.Instruction::i64_lt_s()) ||
  self.proves_instr(@lib.Instruction::i64_lt_u()) ||
  self.proves_instr(@lib.Instruction::i64_gt_s()) ||
  self.proves_instr(@lib.Instruction::i64_gt_u()) ||
  self.proves_instr(@lib.Instruction::i64_le_s()) ||
  self.proves_instr(@lib.Instruction::i64_le_u()) ||
  self.proves_instr(@lib.Instruction::i64_ge_s()) ||
  self.proves_instr(@lib.Instruction::i64_ge_u())
}

///|
fn OiOrderedBinaryLocalLocalEqualityFact::proves_f32_nontrapping_scalar(
  self : OiOrderedBinaryLocalLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::f32_add()) ||
  self.proves_instr(@lib.Instruction::f32_sub()) ||
  self.proves_instr(@lib.Instruction::f32_mul()) ||
  self.proves_instr(@lib.Instruction::f32_div()) ||
  self.proves_instr(@lib.Instruction::f32_min()) ||
  self.proves_instr(@lib.Instruction::f32_max()) ||
  self.proves_instr(@lib.Instruction::f32_copysign()) ||
  self.proves_instr(@lib.Instruction::f32_eq()) ||
  self.proves_instr(@lib.Instruction::f32_ne()) ||
  self.proves_instr(@lib.Instruction::f32_lt()) ||
  self.proves_instr(@lib.Instruction::f32_gt()) ||
  self.proves_instr(@lib.Instruction::f32_le()) ||
  self.proves_instr(@lib.Instruction::f32_ge())
}

///|
fn OiOrderedBinaryLocalLocalEqualityFact::proves_f64_nontrapping_scalar(
  self : OiOrderedBinaryLocalLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::f64_add()) ||
  self.proves_instr(@lib.Instruction::f64_sub()) ||
  self.proves_instr(@lib.Instruction::f64_mul()) ||
  self.proves_instr(@lib.Instruction::f64_div()) ||
  self.proves_instr(@lib.Instruction::f64_min()) ||
  self.proves_instr(@lib.Instruction::f64_max()) ||
  self.proves_instr(@lib.Instruction::f64_copysign()) ||
  self.proves_instr(@lib.Instruction::f64_eq()) ||
  self.proves_instr(@lib.Instruction::f64_ne()) ||
  self.proves_instr(@lib.Instruction::f64_lt()) ||
  self.proves_instr(@lib.Instruction::f64_gt()) ||
  self.proves_instr(@lib.Instruction::f64_le()) ||
  self.proves_instr(@lib.Instruction::f64_ge())
}

///|
priv struct OiOrderedBinaryLocalConstEqualityFact {
  instr : @lib.Instruction?
  matching_i32_local_const_operands : Bool
  matching_i64_local_const_operands : Bool
  matching_f32_local_const_operands : Bool
  matching_f64_local_const_operands : Bool
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::from_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> OiOrderedBinaryLocalConstEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` treats equal binary nodes as the
  // same operation with recursively equal ordered operands. For the select-arm
  // `!condition.invalidates(value)` path, this fact records the represented
  // nontrapping ordered local+constant subset whose local operand cannot be
  // invalidated by an effectful condition and whose constant operand is stable.
  let mut instr : @lib.Instruction? = None
  let mut matching_i32_local_const_operands = false
  let mut matching_i64_local_const_operands = false
  let mut matching_f32_local_const_operands = false
  let mut matching_f64_local_const_operands = false
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) if lhs_instr == rhs_instr => {
      instr = Some(lhs_instr)
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      let mut matching_local_operand = false
      match
        (
          OiLocalGetLeafFact::from_node(func, dead, lhs_left).local_id,
          OiLocalGetLeafFact::from_node(func, dead, rhs_left).local_id,
        ) {
        (Some(lhs_local), Some(rhs_local)) =>
          matching_local_operand = lhs_local == rhs_local
        _ => ()
      }
      if matching_local_operand {
        match
          (
            optimize_instructions_i32_const(func, dead, lhs_right),
            optimize_instructions_i32_const(func, dead, rhs_right),
          ) {
          (Some(lhs_const), Some(rhs_const)) =>
            matching_i32_local_const_operands = lhs_const == rhs_const
          _ => ()
        }
        match
          (
            optimize_instructions_i64_const(func, dead, lhs_right),
            optimize_instructions_i64_const(func, dead, rhs_right),
          ) {
          (Some(lhs_const), Some(rhs_const)) =>
            matching_i64_local_const_operands = lhs_const == rhs_const
          _ => ()
        }
        match
          (
            optimize_instructions_f32_const(func, dead, lhs_right),
            optimize_instructions_f32_const(func, dead, rhs_right),
          ) {
          (Some(lhs_const), Some(rhs_const)) =>
            matching_f32_local_const_operands = lhs_const == rhs_const
          _ => ()
        }
        match
          (
            optimize_instructions_f64_const(func, dead, lhs_right),
            optimize_instructions_f64_const(func, dead, rhs_right),
          ) {
          (Some(lhs_const), Some(rhs_const)) =>
            matching_f64_local_const_operands = lhs_const == rhs_const
          _ => ()
        }
      }
    }
    _ => ()
  }
  {
    instr,
    matching_i32_local_const_operands,
    matching_i64_local_const_operands,
    matching_f32_local_const_operands,
    matching_f64_local_const_operands,
  }
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_instr(
  self : OiOrderedBinaryLocalConstEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  match self.instr {
    Some(actual) => actual == instr
    None => false
  }
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_i32_instr(
  self : OiOrderedBinaryLocalConstEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  self.matching_i32_local_const_operands && self.proves_instr(instr)
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_i64_instr(
  self : OiOrderedBinaryLocalConstEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  self.matching_i64_local_const_operands && self.proves_instr(instr)
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_f32_instr(
  self : OiOrderedBinaryLocalConstEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  self.matching_f32_local_const_operands && self.proves_instr(instr)
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_f64_instr(
  self : OiOrderedBinaryLocalConstEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  self.matching_f64_local_const_operands && self.proves_instr(instr)
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_i32_nontrapping_scalar(
  self : OiOrderedBinaryLocalConstEqualityFact,
) -> Bool {
  self.proves_i32_instr(@lib.Instruction::i32_add()) ||
  self.proves_i32_instr(@lib.Instruction::i32_sub()) ||
  self.proves_i32_instr(@lib.Instruction::i32_mul()) ||
  self.proves_i32_instr(@lib.Instruction::i32_and()) ||
  self.proves_i32_instr(@lib.Instruction::i32_or()) ||
  self.proves_i32_instr(@lib.Instruction::i32_xor()) ||
  self.proves_i32_instr(@lib.Instruction::i32_shl()) ||
  self.proves_i32_instr(@lib.Instruction::i32_shr_s()) ||
  self.proves_i32_instr(@lib.Instruction::i32_shr_u()) ||
  self.proves_i32_instr(@lib.Instruction::i32_rotl()) ||
  self.proves_i32_instr(@lib.Instruction::i32_rotr()) ||
  self.proves_i32_instr(@lib.Instruction::i32_eq()) ||
  self.proves_i32_instr(@lib.Instruction::i32_ne()) ||
  self.proves_i32_instr(@lib.Instruction::i32_lt_s()) ||
  self.proves_i32_instr(@lib.Instruction::i32_lt_u()) ||
  self.proves_i32_instr(@lib.Instruction::i32_gt_s()) ||
  self.proves_i32_instr(@lib.Instruction::i32_gt_u()) ||
  self.proves_i32_instr(@lib.Instruction::i32_le_s()) ||
  self.proves_i32_instr(@lib.Instruction::i32_le_u()) ||
  self.proves_i32_instr(@lib.Instruction::i32_ge_s()) ||
  self.proves_i32_instr(@lib.Instruction::i32_ge_u())
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_i64_nontrapping_scalar(
  self : OiOrderedBinaryLocalConstEqualityFact,
) -> Bool {
  self.proves_i64_instr(@lib.Instruction::i64_add()) ||
  self.proves_i64_instr(@lib.Instruction::i64_sub()) ||
  self.proves_i64_instr(@lib.Instruction::i64_mul()) ||
  self.proves_i64_instr(@lib.Instruction::i64_and()) ||
  self.proves_i64_instr(@lib.Instruction::i64_or()) ||
  self.proves_i64_instr(@lib.Instruction::i64_xor()) ||
  self.proves_i64_instr(@lib.Instruction::i64_shl()) ||
  self.proves_i64_instr(@lib.Instruction::i64_shr_s()) ||
  self.proves_i64_instr(@lib.Instruction::i64_shr_u()) ||
  self.proves_i64_instr(@lib.Instruction::i64_rotl()) ||
  self.proves_i64_instr(@lib.Instruction::i64_rotr()) ||
  self.proves_i64_instr(@lib.Instruction::i64_eq()) ||
  self.proves_i64_instr(@lib.Instruction::i64_ne()) ||
  self.proves_i64_instr(@lib.Instruction::i64_lt_s()) ||
  self.proves_i64_instr(@lib.Instruction::i64_lt_u()) ||
  self.proves_i64_instr(@lib.Instruction::i64_gt_s()) ||
  self.proves_i64_instr(@lib.Instruction::i64_gt_u()) ||
  self.proves_i64_instr(@lib.Instruction::i64_le_s()) ||
  self.proves_i64_instr(@lib.Instruction::i64_le_u()) ||
  self.proves_i64_instr(@lib.Instruction::i64_ge_s()) ||
  self.proves_i64_instr(@lib.Instruction::i64_ge_u())
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_f32_nontrapping_scalar(
  self : OiOrderedBinaryLocalConstEqualityFact,
) -> Bool {
  self.proves_f32_instr(@lib.Instruction::f32_add()) ||
  self.proves_f32_instr(@lib.Instruction::f32_sub()) ||
  self.proves_f32_instr(@lib.Instruction::f32_mul()) ||
  self.proves_f32_instr(@lib.Instruction::f32_div()) ||
  self.proves_f32_instr(@lib.Instruction::f32_min()) ||
  self.proves_f32_instr(@lib.Instruction::f32_max()) ||
  self.proves_f32_instr(@lib.Instruction::f32_copysign()) ||
  self.proves_f32_instr(@lib.Instruction::f32_eq()) ||
  self.proves_f32_instr(@lib.Instruction::f32_ne()) ||
  self.proves_f32_instr(@lib.Instruction::f32_lt()) ||
  self.proves_f32_instr(@lib.Instruction::f32_gt()) ||
  self.proves_f32_instr(@lib.Instruction::f32_le()) ||
  self.proves_f32_instr(@lib.Instruction::f32_ge())
}

///|
fn OiOrderedBinaryLocalConstEqualityFact::proves_f64_nontrapping_scalar(
  self : OiOrderedBinaryLocalConstEqualityFact,
) -> Bool {
  self.proves_f64_instr(@lib.Instruction::f64_add()) ||
  self.proves_f64_instr(@lib.Instruction::f64_sub()) ||
  self.proves_f64_instr(@lib.Instruction::f64_mul()) ||
  self.proves_f64_instr(@lib.Instruction::f64_div()) ||
  self.proves_f64_instr(@lib.Instruction::f64_min()) ||
  self.proves_f64_instr(@lib.Instruction::f64_max()) ||
  self.proves_f64_instr(@lib.Instruction::f64_copysign()) ||
  self.proves_f64_instr(@lib.Instruction::f64_eq()) ||
  self.proves_f64_instr(@lib.Instruction::f64_ne()) ||
  self.proves_f64_instr(@lib.Instruction::f64_lt()) ||
  self.proves_f64_instr(@lib.Instruction::f64_gt()) ||
  self.proves_f64_instr(@lib.Instruction::f64_le()) ||
  self.proves_f64_instr(@lib.Instruction::f64_ge())
}

///|
priv struct OiUnaryLocalEqualityFact {
  instr : @lib.Instruction?
  matching_local_operand : Bool
}

///|
fn OiUnaryLocalEqualityFact::from_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> OiUnaryLocalEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` treats equal unary nodes as the
  // same operation with recursively equal operands. For the select-arm
  // `!condition.invalidates(value)` path, this Starshine fact records the
  // represented nontrapping subset whose operand is a direct local and can be
  // re-evaluated after an effectful condition without reading mutable state.
  let mut instr : @lib.Instruction? = None
  let mut matching_local_operand = false
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 1, 1) if lhs_instr == rhs_instr => {
      instr = Some(lhs_instr)
      let lhs_child = @ir.hot_child_get(func, lhs, 0)
      let rhs_child = @ir.hot_child_get(func, rhs, 0)
      match
        (
          OiLocalGetLeafFact::from_node(func, dead, lhs_child).local_id,
          OiLocalGetLeafFact::from_node(func, dead, rhs_child).local_id,
        ) {
        (Some(lhs_local), Some(rhs_local)) =>
          matching_local_operand = lhs_local == rhs_local
        _ => ()
      }
    }
    _ => ()
  }
  { instr, matching_local_operand }
}

///|
fn OiUnaryLocalEqualityFact::proves_instr(
  self : OiUnaryLocalEqualityFact,
  instr : @lib.Instruction,
) -> Bool {
  if !self.matching_local_operand {
    return false
  }
  match self.instr {
    Some(actual) => actual == instr
    None => false
  }
}

///|
fn OiUnaryLocalEqualityFact::proves_i32_nontrapping_scalar(
  self : OiUnaryLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::i32_eqz()) ||
  self.proves_instr(@lib.Instruction::i32_clz()) ||
  self.proves_instr(@lib.Instruction::i32_ctz()) ||
  self.proves_instr(@lib.Instruction::i32_popcnt()) ||
  self.proves_instr(@lib.Instruction::i32_extend8s()) ||
  self.proves_instr(@lib.Instruction::i32_extend16s()) ||
  self.proves_instr(@lib.Instruction::i32_trunc_sat_f32s()) ||
  self.proves_instr(@lib.Instruction::i32_trunc_sat_f32u()) ||
  self.proves_instr(@lib.Instruction::i32_trunc_sat_f64s()) ||
  self.proves_instr(@lib.Instruction::i32_trunc_sat_f64u()) ||
  self.proves_instr(@lib.Instruction::i32_reinterpret_f32()) ||
  self.proves_instr(@lib.Instruction::i32_wrap_i64())
}

///|
fn OiUnaryLocalEqualityFact::proves_i64_nontrapping_scalar(
  self : OiUnaryLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::i64_eqz()) ||
  self.proves_instr(@lib.Instruction::i64_clz()) ||
  self.proves_instr(@lib.Instruction::i64_ctz()) ||
  self.proves_instr(@lib.Instruction::i64_popcnt()) ||
  self.proves_instr(@lib.Instruction::i64_extend8s()) ||
  self.proves_instr(@lib.Instruction::i64_extend16s()) ||
  self.proves_instr(@lib.Instruction::i64_extend32s()) ||
  self.proves_instr(@lib.Instruction::i64_extend_i32s()) ||
  self.proves_instr(@lib.Instruction::i64_extend_i32u()) ||
  self.proves_instr(@lib.Instruction::i64_trunc_sat_f32s()) ||
  self.proves_instr(@lib.Instruction::i64_trunc_sat_f32u()) ||
  self.proves_instr(@lib.Instruction::i64_trunc_sat_f64s()) ||
  self.proves_instr(@lib.Instruction::i64_trunc_sat_f64u()) ||
  self.proves_instr(@lib.Instruction::i64_reinterpret_f64())
}

///|
fn OiUnaryLocalEqualityFact::proves_f32_nontrapping_scalar(
  self : OiUnaryLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::f32_abs()) ||
  self.proves_instr(@lib.Instruction::f32_neg()) ||
  self.proves_instr(@lib.Instruction::f32_ceil()) ||
  self.proves_instr(@lib.Instruction::f32_floor()) ||
  self.proves_instr(@lib.Instruction::f32_trunc()) ||
  self.proves_instr(@lib.Instruction::f32_nearest()) ||
  self.proves_instr(@lib.Instruction::f32_sqrt()) ||
  self.proves_instr(@lib.Instruction::f32_convert_i32s()) ||
  self.proves_instr(@lib.Instruction::f32_convert_i32u()) ||
  self.proves_instr(@lib.Instruction::f32_convert_i64s()) ||
  self.proves_instr(@lib.Instruction::f32_convert_i64u()) ||
  self.proves_instr(@lib.Instruction::f32_demote_f64()) ||
  self.proves_instr(@lib.Instruction::f32_reinterpret_i32())
}

///|
fn OiUnaryLocalEqualityFact::proves_f64_nontrapping_scalar(
  self : OiUnaryLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::f64_abs()) ||
  self.proves_instr(@lib.Instruction::f64_neg()) ||
  self.proves_instr(@lib.Instruction::f64_ceil()) ||
  self.proves_instr(@lib.Instruction::f64_floor()) ||
  self.proves_instr(@lib.Instruction::f64_trunc()) ||
  self.proves_instr(@lib.Instruction::f64_nearest()) ||
  self.proves_instr(@lib.Instruction::f64_sqrt()) ||
  self.proves_instr(@lib.Instruction::f64_convert_i32s()) ||
  self.proves_instr(@lib.Instruction::f64_convert_i32u()) ||
  self.proves_instr(@lib.Instruction::f64_convert_i64s()) ||
  self.proves_instr(@lib.Instruction::f64_convert_i64u()) ||
  self.proves_instr(@lib.Instruction::f64_promote_f32()) ||
  self.proves_instr(@lib.Instruction::f64_reinterpret_i64())
}

///|
fn OiUnaryLocalEqualityFact::proves_v128_splat(
  self : OiUnaryLocalEqualityFact,
) -> Bool {
  self.proves_instr(@lib.Instruction::i8x16_splat()) ||
  self.proves_instr(@lib.Instruction::i16x8_splat()) ||
  self.proves_instr(@lib.Instruction::i32x4_splat()) ||
  self.proves_instr(@lib.Instruction::i64x2_splat()) ||
  self.proves_instr(@lib.Instruction::f32x4_splat()) ||
  self.proves_instr(@lib.Instruction::f64x2_splat())
}

///|
priv struct OiSimdLeafEqualityFact {
  matching_v128_const_leaf : Bool
  matching_v128_local_splat : Bool
}

///|
fn OiSimdLeafEqualityFact::from_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> OiSimdLeafEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` treats equal SIMD constants as
  // equal leaves and equal splats as equal unary nodes. Keep Starshine's
  // represented select-arm SIMD subset as a fact so the pure-arm fold no
  // longer relies on standalone helper-level SIMD scanners.
  let matching_v128_const_leaf = match
    (@ir.hot_node_exact_instr(func, lhs), @ir.hot_node_exact_instr(func, rhs)) {
    (
      Some(
        @lib.Instruction::V128Const(
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _
        ) as lhs_instr
      ),
      Some(
        @lib.Instruction::V128Const(
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _,
          _
        ) as rhs_instr
      ),
    ) => lhs_instr == rhs_instr
    _ => false
  }
  {
    matching_v128_const_leaf,
    matching_v128_local_splat: OiUnaryLocalEqualityFact::from_nodes(
      func, dead, lhs, rhs,
    ).proves_v128_splat(),
  }
}

///|
priv struct OiRefI31PayloadEqualityFact {
  has_ref_i31_pair : Bool
  matching_local_payload : Bool
  matching_const_payload : Bool
  matching_i32_local_local_scalar : Bool
  matching_i32_local_const_scalar : Bool
  matching_i32_unary_local_scalar : Bool
}

///|
fn OiRefI31PayloadEqualityFact::from_nodes(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> OiRefI31PayloadEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` compares `ref.i31` by comparing
  // its scalar payload. When the enclosing select condition is effectful,
  // `visitSelect` also asks `EffectAnalyzer::invalidates` whether the value can
  // be moved after the condition. Keep Starshine's represented nontrapping,
  // reorderable i31-payload subset as a fact so callers do not re-open a
  // visitor-local ref.i31 scanner.
  let mut has_ref_i31_pair = false
  let mut matching_local_payload = false
  let mut matching_const_payload = false
  let mut matching_i32_local_local_scalar = false
  let mut matching_i32_local_const_scalar = false
  let mut matching_i32_unary_local_scalar = false
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(@lib.Instruction::RefI31), Some(@lib.Instruction::RefI31), 1, 1) => {
      has_ref_i31_pair = true
      let lhs_payload = @ir.hot_child_get(func, lhs, 0)
      let rhs_payload = @ir.hot_child_get(func, rhs, 0)
      match
        (
          OiLocalGetLeafFact::from_node(func, dead, lhs_payload).local_id,
          OiLocalGetLeafFact::from_node(func, dead, rhs_payload).local_id,
        ) {
        (Some(lhs_local), Some(rhs_local)) =>
          matching_local_payload = lhs_local == rhs_local
        _ => ()
      }
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_payload),
          optimize_instructions_i32_const(func, dead, rhs_payload),
        ) {
        (Some(lhs_const), Some(rhs_const)) =>
          matching_const_payload = lhs_const == rhs_const
        _ => ()
      }
      matching_i32_local_local_scalar = OiOrderedBinaryLocalLocalEqualityFact::from_nodes(
        func, dead, lhs_payload, rhs_payload,
      ).proves_i32_nontrapping_scalar()
      matching_i32_local_const_scalar = OiOrderedBinaryLocalConstEqualityFact::from_nodes(
        func, dead, lhs_payload, rhs_payload,
      ).proves_i32_nontrapping_scalar()
      matching_i32_unary_local_scalar = OiUnaryLocalEqualityFact::from_nodes(
        func, dead, lhs_payload, rhs_payload,
      ).proves_i32_nontrapping_scalar()
    }
    _ => ()
  }
  {
    has_ref_i31_pair,
    matching_local_payload,
    matching_const_payload,
    matching_i32_local_local_scalar,
    matching_i32_local_const_scalar,
    matching_i32_unary_local_scalar,
  }
}

///|
fn OiRefI31PayloadEqualityFact::proves_nontrapping_reorderable(
  self : OiRefI31PayloadEqualityFact,
) -> Bool {
  self.has_ref_i31_pair &&
  (
    self.matching_local_payload ||
    self.matching_const_payload ||
    self.matching_i32_local_local_scalar ||
    self.matching_i32_local_const_scalar ||
    self.matching_i32_unary_local_scalar
  )
}

///|
priv struct OiNontrappingReorderableExpressionEqualityFact {
  matching_ref_i31_payload : Bool
  matching_i32_local_local_scalar : Bool
  matching_i64_local_local_scalar : Bool
  matching_i32_local_const_scalar : Bool
  matching_i64_local_const_scalar : Bool
  matching_i32_unary_local_scalar : Bool
  matching_i64_unary_local_scalar : Bool
  matching_f32_scalar : Bool
  matching_f64_scalar : Bool
}

///|
fn OiNontrappingReorderableExpressionEqualityFact::from_select_arms(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  if_true : Int,
  if_false : Int,
) -> OiNontrappingReorderableExpressionEqualityFact {
  // Binaryen v130 `visitSelect` preserves an effectful condition before a
  // folded identical arm only when the condition does not invalidate the value's
  // effects (`!condition.invalidates(value)`). This source-backed fact records
  // the represented nontrapping, local/constant-only equality families that can
  // safely be re-evaluated after the dropped condition instead of leaving them
  // as a visitor-local opcode cascade.
  let ordered_binary_local_local = OiOrderedBinaryLocalLocalEqualityFact::from_nodes(
    func, dead, if_true, if_false,
  )
  let unary_local = OiUnaryLocalEqualityFact::from_nodes(
    func, dead, if_true, if_false,
  )
  let ordered_binary_local_const = OiOrderedBinaryLocalConstEqualityFact::from_nodes(
    func, dead, if_true, if_false,
  )
  {
    matching_ref_i31_payload: OiRefI31PayloadEqualityFact::from_nodes(
      func, dead, if_true, if_false,
    ).proves_nontrapping_reorderable(),
    matching_i32_local_local_scalar: ordered_binary_local_local.proves_i32_nontrapping_scalar(),
    matching_i64_local_local_scalar: ordered_binary_local_local.proves_i64_nontrapping_scalar(),
    matching_i32_local_const_scalar: ordered_binary_local_const.proves_i32_nontrapping_scalar(),
    matching_i64_local_const_scalar: ordered_binary_local_const.proves_i64_nontrapping_scalar(),
    matching_i32_unary_local_scalar: unary_local.proves_i32_nontrapping_scalar(),
    matching_i64_unary_local_scalar: unary_local.proves_i64_nontrapping_scalar(),
    matching_f32_scalar: ordered_binary_local_local.proves_f32_nontrapping_scalar() ||
    unary_local.proves_f32_nontrapping_scalar() ||
    ordered_binary_local_const.proves_f32_nontrapping_scalar(),
    matching_f64_scalar: ordered_binary_local_local.proves_f64_nontrapping_scalar() ||
    unary_local.proves_f64_nontrapping_scalar() ||
    ordered_binary_local_const.proves_f64_nontrapping_scalar(),
  }
}

///|
fn OiNontrappingReorderableExpressionEqualityFact::proves_equal(
  self : OiNontrappingReorderableExpressionEqualityFact,
) -> Bool {
  self.matching_ref_i31_payload ||
  self.matching_i32_local_local_scalar ||
  self.matching_i64_local_local_scalar ||
  self.matching_i32_local_const_scalar ||
  self.matching_i64_local_const_scalar ||
  self.matching_i32_unary_local_scalar ||
  self.matching_i64_unary_local_scalar ||
  self.matching_f32_scalar ||
  self.matching_f64_scalar
}

///|
priv struct OiIdenticalPureExpressionFact {
  operands_are_effect_safe : Bool
  matching_pure_scalar_tree : Bool
  matching_stable_state_read : Bool
  matching_stable_state_scalar_tree : Bool
  matching_reference_leaf : Bool
  matching_ref_i31_scalar_tree : Bool
  matching_ref_i31_nontrapping_local_scalar_tree : Bool
  matching_v128_const_leaf : Bool
  matching_v128_local_splat : Bool
  matching_nontrapping_reorderable_scalar_tree : Bool
}

///|
priv struct OiReferenceLeafEqualityFact {
  matching_ref_null_leaf : Bool
  matching_ref_func_leaf : Bool
}

///|
fn OiReferenceLeafEqualityFact::from_nodes(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> OiReferenceLeafEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` compares reference leaves by
  // their literal heap/function target. Starshine also accepts HOT-lowered
  // RefNull/RefFunc node payloads whose result types preserve the reference
  // type. Keep that represented subset as a fact instead of an arm-local helper
  // scanner.
  let mut matching_ref_null_leaf = false
  let mut matching_ref_func_leaf = false
  match (@ir.hot_node_get(func, lhs_id), @ir.hot_node_get(func, rhs_id)) {
    (
      { op: @ir.HotOp::RefNull, ty: lhs_ty, .. },
      { op: @ir.HotOp::RefNull, ty: rhs_ty, .. },
    ) => matching_ref_null_leaf = lhs_ty == rhs_ty
    (
      { op: @ir.HotOp::RefFunc, ty: lhs_ty, imm0: lhs_func, .. },
      { op: @ir.HotOp::RefFunc, ty: rhs_ty, imm0: rhs_func, .. },
    ) => matching_ref_func_leaf = lhs_ty == rhs_ty && lhs_func == rhs_func
    _ => ()
  }
  if !matching_ref_null_leaf && !matching_ref_func_leaf {
    match
      (
        @ir.hot_node_exact_instr(func, lhs_id),
        @ir.hot_node_exact_instr(func, rhs_id),
      ) {
      (
        Some(@lib.Instruction::RefNull(lhs)),
        Some(@lib.Instruction::RefNull(rhs)),
      ) => matching_ref_null_leaf = lhs == rhs
      (
        Some(@lib.Instruction::RefFunc(lhs)),
        Some(@lib.Instruction::RefFunc(rhs)),
      ) => matching_ref_func_leaf = lhs == rhs
      _ => ()
    }
  }
  { matching_ref_null_leaf, matching_ref_func_leaf }
}

///|
fn OiReferenceLeafEqualityFact::proves_equal(
  self : OiReferenceLeafEqualityFact,
) -> Bool {
  self.matching_ref_null_leaf || self.matching_ref_func_leaf
}

///|
priv struct OiLocalConstSelectScalarTreeFact {
  nontrapping_reorderable : Bool
}

///|
fn OiLocalConstSelectScalarTreeFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
  depth? : Int = 0,
) -> OiLocalConstSelectScalarTreeFact {
  // Same-value select-arm folding across an effectful condition moves the kept
  // value after that condition. This fact is the source-backed, represented
  // scalar subset that cannot trap and cannot observe calls, globals, memory,
  // or tables: local/const leaves plus branchless select shells whose arms and
  // condition recursively have the same property.
  if depth > 16 {
    return { nontrapping_reorderable: false }
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::Const => { nontrapping_reorderable: true }
    @ir.HotOp::Select => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !OiLocalConstSelectScalarTreeFact::from_node(
            func,
            @ir.hot_child_get(func, node_id, slot),
            depth=depth + 1,
          ).proves_nontrapping_reorderable() {
          return { nontrapping_reorderable: false }
        }
      }
      { nontrapping_reorderable: true }
    }
    _ => { nontrapping_reorderable: false }
  }
}

///|
fn OiLocalConstSelectScalarTreeFact::proves_nontrapping_reorderable(
  self : OiLocalConstSelectScalarTreeFact,
) -> Bool {
  self.nontrapping_reorderable
}

///|
priv struct OiRefI31ScalarTreeEqualityFact {
  has_ref_i31_pair : Bool
  matching_pure_payload_tree : Bool
  payloads_are_nontrapping_reorderable : Bool
}

///|
fn OiRefI31ScalarTreeEqualityFact::from_nodes(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> OiRefI31ScalarTreeEqualityFact {
  // Binaryen v130 `ExpressionAnalyzer::equal` compares `ref.i31` shells by
  // recursively comparing their i32 payloads. Binaryen `visitSelect` then uses
  // `EffectAnalyzer::invalidates` before moving equal arms across an effectful
  // condition; Starshine's represented safe-move subset is local/const/select
  // scalar payload trees. Keep both payload equality and movability as explicit
  // fact fields rather than helper-level ref.i31 tree scanners.
  let mut has_ref_i31_pair = false
  let mut matching_pure_payload_tree = false
  let mut payloads_are_nontrapping_reorderable = false
  let lhs = @ir.hot_node_get(func, lhs_id)
  let rhs = @ir.hot_node_get(func, rhs_id)
  if lhs.ty == rhs.ty && lhs.child_count == 1 && rhs.child_count == 1 {
    match
      (
        @ir.hot_node_exact_instr(func, lhs_id),
        @ir.hot_node_exact_instr(func, rhs_id),
      ) {
      (Some(@lib.Instruction::RefI31), Some(@lib.Instruction::RefI31)) => {
        has_ref_i31_pair = true
        let lhs_payload = @ir.hot_child_get(func, lhs_id, 0)
        let rhs_payload = @ir.hot_child_get(func, rhs_id, 0)
        matching_pure_payload_tree = OiScalarTreeEqualityFact::from_nodes(
          func, lhs_payload, rhs_payload,
        ).proves_pure_equal()
        payloads_are_nontrapping_reorderable = OiLocalConstSelectScalarTreeFact::from_node(
            func, lhs_payload,
          ).proves_nontrapping_reorderable() &&
          OiLocalConstSelectScalarTreeFact::from_node(func, rhs_payload).proves_nontrapping_reorderable()
      }
      _ => ()
    }
  }
  {
    has_ref_i31_pair,
    matching_pure_payload_tree,
    payloads_are_nontrapping_reorderable,
  }
}

///|
fn OiRefI31ScalarTreeEqualityFact::proves_pure_equal(
  self : OiRefI31ScalarTreeEqualityFact,
) -> Bool {
  self.has_ref_i31_pair && self.matching_pure_payload_tree
}

///|
fn OiRefI31ScalarTreeEqualityFact::proves_nontrapping_reorderable_equal(
  self : OiRefI31ScalarTreeEqualityFact,
) -> Bool {
  self.has_ref_i31_pair &&
  self.matching_pure_payload_tree &&
  self.payloads_are_nontrapping_reorderable
}

///|
fn OiIdenticalPureExpressionFact::from_select_arms(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  if_true : Int,
  if_false : Int,
) -> OiIdenticalPureExpressionFact {
  // Binaryen v130 `visitSelect` folds identical arms via
  // `ExpressionAnalyzer::equal(ifTrue, ifFalse)` after checking whether the
  // arms have effects. Model Starshine's represented no-side-effect/effect-safe
  // subset as an explicit fact shared by nested scalar/select trees,
  // deterministic state-read leaves, deterministic reference leaves, represented
  // ref.i31 scalar-payload trees, and the currently represented SIMD constant /
  // local-splat leaves instead of growing the old opcode-by-opcode arm scanner.
  // State-read leaves stay separated from pure scalar equality so
  // effectful-condition folds do not move memory/table-size reads across possible
  // growth.
  let left = @ir.hot_node_get(func, if_true)
  let right = @ir.hot_node_get(func, if_false)
  let scalar_tree_fact = OiScalarTreeEqualityFact::from_nodes(
    func, if_true, if_false,
  )
  let state_scalar_tree_fact = OiScalarTreeEqualityFact::from_nodes(
    func,
    if_true,
    if_false,
    include_stable_state_read=true,
  )
  let scalar_tree = scalar_tree_fact.proves_pure_equal()
  let state_read = OiStableStateReadEqualityFact::from_nodes(left, right).proves_equal()
  let state_scalar_tree = state_scalar_tree_fact.proves_stable_state_scalar_equal()
  let reference_leaf = OiReferenceLeafEqualityFact::from_nodes(
    func, if_true, if_false,
  ).proves_equal()
  let ref_i31_scalar_tree_fact = OiRefI31ScalarTreeEqualityFact::from_nodes(
    func, if_true, if_false,
  )
  let ref_i31_scalar_tree = ref_i31_scalar_tree_fact.proves_pure_equal()
  let ref_i31_nontrapping_local_scalar_tree = ref_i31_scalar_tree_fact.proves_nontrapping_reorderable_equal()
  let simd_leaf = OiSimdLeafEqualityFact::from_nodes(
    func, dead, if_true, if_false,
  )
  let nontrapping_reorderable_scalar_tree = OiNontrappingReorderableExpressionEqualityFact::from_select_arms(
    func, dead, if_true, if_false,
  ).proves_equal()
  let effect_safe = if state_read || state_scalar_tree {
    true
  } else {
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, if_true) &&
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, if_false)
  }
  if !effect_safe {
    return {
      operands_are_effect_safe: false,
      matching_pure_scalar_tree: false,
      matching_stable_state_read: false,
      matching_stable_state_scalar_tree: false,
      matching_reference_leaf: false,
      matching_ref_i31_scalar_tree: false,
      matching_ref_i31_nontrapping_local_scalar_tree: false,
      matching_v128_const_leaf: false,
      matching_v128_local_splat: false,
      matching_nontrapping_reorderable_scalar_tree: false,
    }
  }
  {
    operands_are_effect_safe: true,
    matching_pure_scalar_tree: scalar_tree,
    matching_stable_state_read: state_read,
    matching_stable_state_scalar_tree: state_scalar_tree,
    matching_reference_leaf: reference_leaf,
    matching_ref_i31_scalar_tree: ref_i31_scalar_tree,
    matching_ref_i31_nontrapping_local_scalar_tree: ref_i31_nontrapping_local_scalar_tree,
    matching_v128_const_leaf: simd_leaf.matching_v128_const_leaf,
    matching_v128_local_splat: simd_leaf.matching_v128_local_splat,
    matching_nontrapping_reorderable_scalar_tree: nontrapping_reorderable_scalar_tree,
  }
}

///|
fn OiIdenticalPureExpressionFact::proves_equal(
  self : OiIdenticalPureExpressionFact,
) -> Bool {
  self.operands_are_effect_safe &&
  (
    self.matching_pure_scalar_tree ||
    self.matching_stable_state_read ||
    self.matching_stable_state_scalar_tree ||
    self.matching_reference_leaf ||
    self.matching_ref_i31_scalar_tree ||
    self.matching_ref_i31_nontrapping_local_scalar_tree ||
    self.matching_v128_const_leaf ||
    self.matching_v128_local_splat ||
    self.matching_nontrapping_reorderable_scalar_tree
  )
}

///|
fn optimize_instructions_select_identical_immutable_global_arms(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  if_true : Int,
  if_false : Int,
) -> Bool {
  match (@ir.hot_node_get(func, if_true), @ir.hot_node_get(func, if_false)) {
    (
      { op: @ir.HotOp::GlobalGet, imm0: lhs, .. },
      { op: @ir.HotOp::GlobalGet, imm0: rhs, .. },
    ) if lhs == rhs =>
      match ctx.module_ctx {
        Some(module_ctx) =>
          match
            @ir.hot_module_resolve_global_type(
              module_ctx,
              @lib.GlobalIdx::new(lhs.reinterpret_as_uint()),
            ) {
            Some(@lib.GlobalType(_, false)) => true
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_inverted_select_compare(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32Eq => Some(@lib.Instruction::i32_ne())
    @lib.Instruction::I32Ne => Some(@lib.Instruction::i32_eq())
    @lib.Instruction::I64Eq => Some(@lib.Instruction::i64_ne())
    @lib.Instruction::I64Ne => Some(@lib.Instruction::i64_eq())
    _ => optimize_instructions_inverted_eqz_compare(instr)
  }
}

///|
fn optimize_instructions_try_fold_const_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Select if node.child_count == 3 => ()
    _ => return false
  }
  let if_true = @ir.hot_child_get(func, node_id, 0)
  let if_false = @ir.hot_child_get(func, node_id, 1)
  let condition = @ir.hot_child_get(func, node_id, 2)
  match @ir.hot_node_exact_instr(func, condition) {
    Some(@lib.Instruction::I64Eqz) if @ir.hot_child_count(func, condition) == 1 => {
      let inner_condition = @ir.hot_child_get(func, condition, 0)
      if !OiLiveNodeFact::proves_node_live(func, dead, inner_condition) {
        return false
      }
      match
        (
          optimize_instructions_i32_const(func, dead, if_true),
          optimize_instructions_i32_const(func, dead, if_false),
        ) {
        (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
          optimize_instructions_replace_with_exact_unary(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eqz(),
            inner_condition,
          )
          return true
        }
        (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            inner_condition,
            @ir.hot_build_const_i64(func, @lib.I64(0L)),
          )
          return true
        }
        _ => ()
      }
    }
    Some(@lib.Instruction::I32Eqz) if @ir.hot_child_count(func, condition) == 1 => {
      let inner_condition = @ir.hot_child_get(func, condition, 0)
      if !OiLiveNodeFact::proves_node_live(func, dead, inner_condition) {
        return false
      }
      match
        (
          optimize_instructions_i32_const(func, dead, if_true),
          optimize_instructions_i32_const(func, dead, if_false),
        ) {
        (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
          match @ir.hot_node_exact_instr(func, inner_condition) {
            Some(inner_instr) if @ir.hot_child_count(func, inner_condition) == 2 =>
              match optimize_instructions_inverted_select_compare(inner_instr) {
                Some(inverted_instr) => {
                  let lhs_id = @ir.hot_child_get(func, inner_condition, 0)
                  let rhs_id = @ir.hot_child_get(func, inner_condition, 1)
                  if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) ||
                    !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
                    return false
                  }
                  optimize_instructions_replace_with_exact_compare(
                    ctx, func, node_id, inverted_instr, lhs_id, rhs_id,
                  )
                  return true
                }
                _ => ()
              }
            _ => ()
          }
          optimize_instructions_replace_with_exact_unary(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eqz(),
            inner_condition,
          )
          return true
        }
        (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
          match @ir.hot_node_exact_instr(func, inner_condition) {
            Some(inner_instr) if @ir.hot_child_count(func, inner_condition) == 2 =>
              match optimize_instructions_inverted_select_compare(inner_instr) {
                Some(_) => {
                  optimize_instructions_replace_with_node_id(
                    ctx, func, node_id, inner_condition,
                  )
                  return true
                }
                _ => ()
              }
            _ => ()
          }
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_ne(),
            inner_condition,
            @ir.hot_build_const_i32(func, @lib.I32(0)),
          )
          return true
        }
        _ => ()
      }
      match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
        [result_type] => {
          let replacement = @ir.hot_build_select(
            func, result_type, if_false, if_true, inner_condition,
          )
          optimize_instructions_replace_with_node_id(
            ctx, func, node_id, replacement,
          )
          return true
        }
        _ => ()
      }
    }
    Some(compare_instr) if @ir.hot_child_count(func, condition) == 2 =>
      match compare_instr {
        @lib.Instruction::I32Eq | @lib.Instruction::I32Ne => {
          let lhs_id = @ir.hot_child_get(func, condition, 0)
          let rhs_id = @ir.hot_child_get(func, condition, 1)
          let inner_condition = match
            optimize_instructions_i32_const(func, dead, rhs_id) {
            Some(@lib.I32(raw)) if raw == 0 => Some(lhs_id)
            _ =>
              match optimize_instructions_i32_const(func, dead, lhs_id) {
                Some(@lib.I32(raw)) if raw == 0 => Some(rhs_id)
                _ => None
              }
          }
          match inner_condition {
            Some(inner_condition) => {
              if !OiLiveNodeFact::proves_node_live(func, dead, inner_condition) {
                return false
              }
              let invert_condition = match compare_instr {
                @lib.Instruction::I32Eq => true
                _ => false
              }
              match
                (
                  optimize_instructions_i32_const(func, dead, if_true),
                  optimize_instructions_i32_const(func, dead, if_false),
                ) {
                (Some(@lib.I32(1)), Some(@lib.I32(0))) if invert_condition => {
                  optimize_instructions_replace_with_exact_unary(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i32_eqz(),
                    inner_condition,
                  )
                  return true
                }
                (Some(@lib.I32(0)), Some(@lib.I32(1))) if invert_condition => {
                  optimize_instructions_replace_with_exact_compare(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i32_ne(),
                    inner_condition,
                    @ir.hot_build_const_i32(func, @lib.I32(0)),
                  )
                  return true
                }
                (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
                  optimize_instructions_replace_with_exact_compare(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i32_ne(),
                    inner_condition,
                    @ir.hot_build_const_i32(func, @lib.I32(0)),
                  )
                  return true
                }
                (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
                  optimize_instructions_replace_with_exact_unary(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i32_eqz(),
                    inner_condition,
                  )
                  return true
                }
                _ => ()
              }
              match
                @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
                [result_type] => {
                  let replacement = if invert_condition {
                    @ir.hot_build_select(
                      func, result_type, if_false, if_true, inner_condition,
                    )
                  } else {
                    @ir.hot_build_select(
                      func, result_type, if_true, if_false, inner_condition,
                    )
                  }
                  optimize_instructions_replace_with_node_id(
                    ctx, func, node_id, replacement,
                  )
                  return true
                }
                _ => ()
              }
            }
            _ => ()
          }
        }
        @lib.Instruction::I64Eq | @lib.Instruction::I64Ne => {
          let lhs_id = @ir.hot_child_get(func, condition, 0)
          let rhs_id = @ir.hot_child_get(func, condition, 1)
          let inner_condition = match
            optimize_instructions_i64_const(func, dead, rhs_id) {
            Some(@lib.I64(raw)) if raw == 0L => Some(lhs_id)
            _ =>
              match optimize_instructions_i64_const(func, dead, lhs_id) {
                Some(@lib.I64(raw)) if raw == 0L => Some(rhs_id)
                _ => None
              }
          }
          match inner_condition {
            Some(inner_condition) => {
              if !OiLiveNodeFact::proves_node_live(func, dead, inner_condition) {
                return false
              }
              let invert_condition = match compare_instr {
                @lib.Instruction::I64Eq => true
                _ => false
              }
              match
                (
                  optimize_instructions_i32_const(func, dead, if_true),
                  optimize_instructions_i32_const(func, dead, if_false),
                ) {
                (Some(@lib.I32(1)), Some(@lib.I32(0))) if invert_condition => {
                  optimize_instructions_replace_with_exact_unary(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i64_eqz(),
                    inner_condition,
                  )
                  return true
                }
                (Some(@lib.I32(0)), Some(@lib.I32(1))) if invert_condition => {
                  optimize_instructions_replace_with_exact_compare(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i64_ne(),
                    inner_condition,
                    @ir.hot_build_const_i64(func, @lib.I64(0L)),
                  )
                  return true
                }
                (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
                  optimize_instructions_replace_with_exact_compare(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i64_ne(),
                    inner_condition,
                    @ir.hot_build_const_i64(func, @lib.I64(0L)),
                  )
                  return true
                }
                (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
                  optimize_instructions_replace_with_exact_unary(
                    ctx,
                    func,
                    node_id,
                    @lib.Instruction::i64_eqz(),
                    inner_condition,
                  )
                  return true
                }
                _ => ()
              }
              match
                @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
                [result_type] => {
                  let replacement = if invert_condition {
                    @ir.hot_build_select(
                      func, result_type, if_false, if_true, inner_condition,
                    )
                  } else {
                    @ir.hot_build_select(
                      func, result_type, if_true, if_false, inner_condition,
                    )
                  }
                  optimize_instructions_replace_with_node_id(
                    ctx, func, node_id, replacement,
                  )
                  return true
                }
                _ => ()
              }
            }
            _ => ()
          }
        }
        _ => ()
      }
    _ => ()
  }
  match @ir.hot_node_exact_instr(func, condition) {
    Some(compare_instr) if @ir.hot_child_count(func, condition) == 2 => {
      let lhs_id = @ir.hot_child_get(func, condition, 0)
      let rhs_id = @ir.hot_child_get(func, condition, 1)
      match compare_instr {
        @lib.Instruction::I32Eq
        | @lib.Instruction::I32Ne
        | @lib.Instruction::I64Eq
        | @lib.Instruction::I64Ne =>
          match
            (
              optimize_instructions_i32_const(func, dead, if_true),
              optimize_instructions_i32_const(func, dead, if_false),
            ) {
            (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
              if !OiLiveNodeFact::proves_node_live(func, dead, condition) {
                return false
              }
              optimize_instructions_replace_with_node_id(
                ctx, func, node_id, condition,
              )
              return true
            }
            (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
              if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) ||
                !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
                return false
              }
              let inverted_instr = match compare_instr {
                @lib.Instruction::I32Eq => @lib.Instruction::i32_ne()
                @lib.Instruction::I32Ne => @lib.Instruction::i32_eq()
                @lib.Instruction::I64Eq => @lib.Instruction::i64_ne()
                @lib.Instruction::I64Ne => @lib.Instruction::i64_eq()
                _ => abort("unreachable integer equality compare")
              }
              optimize_instructions_replace_with_exact_compare(
                ctx, func, node_id, inverted_instr, lhs_id, rhs_id,
              )
              return true
            }
            _ => ()
          }
        _ => ()
      }
      match optimize_instructions_inverted_eqz_compare(compare_instr) {
        Some(inverted_instr) =>
          match
            (
              optimize_instructions_i32_const(func, dead, if_true),
              optimize_instructions_i32_const(func, dead, if_false),
            ) {
            (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
              if !OiLiveNodeFact::proves_node_live(func, dead, condition) {
                return false
              }
              optimize_instructions_replace_with_node_id(
                ctx, func, node_id, condition,
              )
              return true
            }
            (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
              let lhs_id = @ir.hot_child_get(func, condition, 0)
              let rhs_id = @ir.hot_child_get(func, condition, 1)
              if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) ||
                !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
                return false
              }
              optimize_instructions_replace_with_exact_compare(
                ctx, func, node_id, inverted_instr, lhs_id, rhs_id,
              )
              return true
            }
            _ => ()
          }
        _ => ()
      }
    }
    _ => ()
  }
  match
    (
      optimize_instructions_i32_const(func, dead, if_true),
      optimize_instructions_i32_const(func, dead, if_false),
    ) {
    (Some(@lib.I32(1)), Some(@lib.I32(0))) => {
      optimize_instructions_replace_with_exact_compare(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_ne(),
        condition,
        @ir.hot_build_const_i32(func, @lib.I32(0)),
      )
      return true
    }
    (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
      optimize_instructions_replace_with_exact_unary(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_eqz(),
        condition,
      )
      return true
    }
    _ => ()
  }
  let identical_arm_fact = OiIdenticalPureExpressionFact::from_select_arms(
    func, dead, if_true, if_false,
  )
  if identical_arm_fact.proves_equal() {
    if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, condition) {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, if_true)
      return true
    }
    if (
        (
          OiSharedCrossSafeLeafFact::from_node(func, dead, if_true).proves_safe() &&
          OiSharedCrossSafeLeafFact::from_node(func, dead, if_false).proves_safe()
        ) ||
        optimize_instructions_select_identical_immutable_global_arms(
          ctx, func, if_true, if_false,
        ) ||
        identical_arm_fact.matching_ref_i31_nontrapping_local_scalar_tree ||
        identical_arm_fact.matching_v128_const_leaf ||
        identical_arm_fact.matching_v128_local_splat ||
        identical_arm_fact.matching_nontrapping_reorderable_scalar_tree
      ) &&
      @ir.hot_node_result_arity(func, if_true) == 1 &&
      @ir.hot_node_result_arity(func, condition) == 1 {
      match @ir.hot_type_results(func, @ir.hot_node_type(func, if_true)) {
        [result_type] => {
          let replacement = @ir.hot_build_block(
            func,
            @lib.BlockType::val_type(result_type),
            [@ir.hot_build_drop(func, condition), if_true],
          )
          optimize_instructions_replace_with_node_id(
            ctx, func, node_id, replacement,
          )
          return true
        }
        _ => ()
      }
    }
  }
  let (chosen, dead_arm) = match
    optimize_instructions_i32_const(func, dead, condition) {
    Some(@lib.I32(raw)) if raw == 0 => (if_false, if_true)
    Some(@lib.I32(_)) => (if_true, if_false)
    _ => return false
  }
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, dead_arm) {
    return false
  }
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, chosen) {
    let use_def = pass_require_use_def(ctx, func)
    if @ir.node_use_count(use_def, chosen) != 1 {
      return false
    }
  }
  optimize_instructions_replace_with_node_id(ctx, func, node_id, chosen)
  true
}

///|
fn optimize_instructions_try_apply_demorgan_and_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32And => ()
    _ => return false
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) ||
    !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
    return false
  }
  match
    (
      @ir.hot_node_exact_instr(func, lhs_id),
      @ir.hot_node_exact_instr(func, rhs_id),
    ) {
    (Some(@lib.Instruction::I32Eqz), Some(@lib.Instruction::I32Eqz)) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, lhs_id) != 1 ||
    @ir.hot_child_count(func, rhs_id) != 1 {
    return false
  }
  let lhs_operand_id = @ir.hot_child_get(func, lhs_id, 0)
  let rhs_operand_id = @ir.hot_child_get(func, rhs_id, 0)
  if !OiLiveNodeFact::proves_node_live(func, dead, lhs_operand_id) ||
    !OiLiveNodeFact::proves_node_live(func, dead, rhs_operand_id) {
    return false
  }
  let or_id = @ir.hot_build_binary(
    func,
    @lib.ValType::i32(),
    lhs_operand_id,
    rhs_operand_id,
  )
  @ir.hot_node_exact_instr_set(func, or_id, @lib.Instruction::i32_or())
  optimize_instructions_replace_with_exact_unary(
    ctx,
    func,
    node_id,
    @lib.Instruction::i32_eqz(),
    or_id,
  )
  true
}

///|
fn optimize_instructions_inverted_eqz_compare(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::F32Eq => Some(@lib.Instruction::f32_ne())
    @lib.Instruction::F32Ne => Some(@lib.Instruction::f32_eq())
    @lib.Instruction::F64Eq => Some(@lib.Instruction::f64_ne())
    @lib.Instruction::F64Ne => Some(@lib.Instruction::f64_eq())
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_ge_s())
    @lib.Instruction::I32LtU => Some(@lib.Instruction::i32_ge_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_gt_s())
    @lib.Instruction::I32LeU => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_le_s())
    @lib.Instruction::I32GtU => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_lt_s())
    @lib.Instruction::I32GeU => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_ge_s())
    @lib.Instruction::I64LtU => Some(@lib.Instruction::i64_ge_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_gt_s())
    @lib.Instruction::I64LeU => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_le_s())
    @lib.Instruction::I64GtU => Some(@lib.Instruction::i64_le_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_lt_s())
    @lib.Instruction::I64GeU => Some(@lib.Instruction::i64_lt_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  if !OiLiveNodeFact::proves_node_live(func, dead, operand_id) {
    return false
  }
  match
    OiEqzWrapI64MaxBitsFact::from_eqz_operand(
      func, dead, scratch, instr, operand_id,
    ) {
    Some(fact) => {
      optimize_instructions_replace_with_exact_unary(
        ctx,
        func,
        node_id,
        @lib.Instruction::i64_eqz(),
        fact.value_id,
      )
      return true
    }
    None => ()
  }
  let operand = func.nodes[operand_id]
  match (instr, operand.op, @ir.hot_node_exact_instr(func, operand_id)) {
    (@lib.Instruction::I32Eqz, @ir.HotOp::Unary, Some(@lib.Instruction::I32Eqz)) => {
      let inner_operand_id = @ir.hot_child_get(func, operand_id, 0)
      if !OiLiveNodeFact::proves_node_live(func, dead, inner_operand_id) {
        return false
      }
      match optimize_instructions_i32_const(func, dead, inner_operand_id) {
        Some(@lib.I32(raw)) => {
          let folded = if raw == 0 { @lib.I32(0) } else { @lib.I32(1) }
          optimize_instructions_replace_with_const_i32(
            ctx, func, node_id, folded,
          )
        }
        None =>
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_ne(),
            inner_operand_id,
            @ir.hot_build_const_i32(func, @lib.I32(0)),
          )
      }
      return true
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Unary, Some(@lib.Instruction::I64Eqz)) => {
      let inner_operand_id = @ir.hot_child_get(func, operand_id, 0)
      if !OiLiveNodeFact::proves_node_live(func, dead, inner_operand_id) {
        return false
      }
      match optimize_instructions_i64_const(func, dead, inner_operand_id) {
        Some(@lib.I64(raw)) => {
          let folded = if raw == 0L { @lib.I32(0) } else { @lib.I32(1) }
          optimize_instructions_replace_with_const_i32(
            ctx, func, node_id, folded,
          )
        }
        None =>
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            inner_operand_id,
            @ir.hot_build_const_i64(func, @lib.I64(0L)),
          )
      }
      return true
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Compare, Some(@lib.Instruction::I32Ne)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(raw)), _) if raw == 0 => {
          optimize_instructions_replace_with_exact_unary(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eqz(),
            rhs_id,
          )
          return true
        }
        (_, Some(@lib.I32(raw))) if raw == 0 => {
          optimize_instructions_replace_with_exact_unary(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eqz(),
            lhs_id,
          )
          return true
        }
        _ => ()
      }
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Compare, Some(@lib.Instruction::I64Ne)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I64(raw)), _) if raw == 0L => {
          optimize_instructions_replace_with_exact_unary(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eqz(),
            rhs_id,
          )
          return true
        }
        (_, Some(@lib.I64(raw))) if raw == 0L => {
          optimize_instructions_replace_with_exact_unary(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eqz(),
            lhs_id,
          )
          return true
        }
        _ => ()
      }
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Compare, Some(@lib.Instruction::I32Eq)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(raw)), _) if raw == 0 => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_ne(),
            rhs_id,
            @ir.hot_build_const_i32(func, @lib.I32(0)),
          )
          return true
        }
        (_, Some(@lib.I32(raw))) if raw == 0 => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_ne(),
            lhs_id,
            @ir.hot_build_const_i32(func, @lib.I32(0)),
          )
          return true
        }
        _ => ()
      }
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Compare, Some(@lib.Instruction::I64Eq)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I64(raw)), _) if raw == 0L => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            rhs_id,
            @ir.hot_build_const_i64(func, @lib.I64(0L)),
          )
          return true
        }
        (_, Some(@lib.I64(raw))) if raw == 0L => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_ne(),
            lhs_id,
            @ir.hot_build_const_i64(func, @lib.I64(0L)),
          )
          return true
        }
        _ => ()
      }
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Compare, Some(compare_instr)) =>
      match optimize_instructions_inverted_eqz_compare(compare_instr) {
        Some(inverted) => {
          let lhs_id = @ir.hot_child_get(func, operand_id, 0)
          let rhs_id = @ir.hot_child_get(func, operand_id, 1)
          optimize_instructions_replace_with_exact_compare(
            ctx, func, node_id, inverted, lhs_id, rhs_id,
          )
          return true
        }
        None => ()
      }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Binary, Some(@lib.Instruction::I32Sub)
    )
    | (
      @lib.Instruction::I64Eqz,
      @ir.HotOp::Binary,
      Some(@lib.Instruction::I64Sub),
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      optimize_instructions_replace_with_exact_compare(
        ctx,
        func,
        node_id,
        match instr {
          @lib.Instruction::I32Eqz => @lib.Instruction::i32_eq()
          _ => @lib.Instruction::i64_eq()
        },
        lhs_id,
        rhs_id,
      )
      return true
    }
    (@lib.Instruction::I32Eqz, @ir.HotOp::Binary, Some(@lib.Instruction::I32Add)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(raw)), _) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eq(),
            rhs_id,
            @ir.hot_build_const_i32(func, @lib.I32(-raw)),
          )
          return true
        }
        (_, Some(@lib.I32(raw))) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_eq(),
            lhs_id,
            @ir.hot_build_const_i32(func, @lib.I32(-raw)),
          )
          return true
        }
        _ => ()
      }
    }
    (@lib.Instruction::I64Eqz, @ir.HotOp::Binary, Some(@lib.Instruction::I64Add)
    ) => {
      let lhs_id = @ir.hot_child_get(func, operand_id, 0)
      let rhs_id = @ir.hot_child_get(func, operand_id, 1)
      match
        (
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I64(raw)), _) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            rhs_id,
            @ir.hot_build_const_i64(func, @lib.I64(-raw)),
          )
          return true
        }
        (_, Some(@lib.I64(raw))) => {
          optimize_instructions_replace_with_exact_compare(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_eq(),
            lhs_id,
            @ir.hot_build_const_i64(func, @lib.I64(-raw)),
          )
          return true
        }
        _ => ()
      }
    }
    _ => ()
  }
  false
}

///|
fn optimize_instructions_try_fold_exact_const_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      instr,
      optimize_instructions_i32_const(func, dead, lhs_id),
      optimize_instructions_i32_const(func, dead, rhs_id),
    ) {
    (@lib.Instruction::I32Add, Some(@lib.I32(lhs_raw)), Some(@lib.I32(rhs_raw))) => {
      let folded = @lib.I32(
        (lhs_raw.reinterpret_as_uint() + rhs_raw.reinterpret_as_uint()).reinterpret_as_int(),
      )
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, folded)
      true
    }
    (@lib.Instruction::I32Sub, Some(@lib.I32(lhs_raw)), Some(@lib.I32(rhs_raw))) => {
      let folded = @lib.I32(
        (lhs_raw.reinterpret_as_uint() - rhs_raw.reinterpret_as_uint()).reinterpret_as_int(),
      )
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, folded)
      true
    }
    _ =>
      match
        (
          instr,
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (
          @lib.Instruction::I64Add,
          Some(@lib.I64(lhs_raw)),
          Some(@lib.I64(rhs_raw)),
        ) => {
          let folded = @lib.I64(
            (lhs_raw.reinterpret_as_uint64() + rhs_raw.reinterpret_as_uint64()).reinterpret_as_int64(),
          )
          optimize_instructions_replace_with_const_i64(
            ctx, func, node_id, folded,
          )
          true
        }
        (
          @lib.Instruction::I64Sub,
          Some(@lib.I64(lhs_raw)),
          Some(@lib.I64(rhs_raw)),
        ) => {
          let folded = @lib.I64(
            (lhs_raw.reinterpret_as_uint64() - rhs_raw.reinterpret_as_uint64()).reinterpret_as_int64(),
          )
          optimize_instructions_replace_with_const_i64(
            ctx, func, node_id, folded,
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_i32_identity_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
  identity : Int,
) -> Int? {
  match
    (
      optimize_instructions_i32_const(func, dead, lhs_id),
      optimize_instructions_i32_const(func, dead, rhs_id),
    ) {
    (Some(@lib.I32(raw)), _) if raw == identity => Some(rhs_id)
    (_, Some(@lib.I32(raw))) if raw == identity => Some(lhs_id)
    _ => None
  }
}

///|
fn optimize_instructions_i64_identity_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
  identity : Int64,
) -> Int? {
  match
    (
      optimize_instructions_i64_const(func, dead, lhs_id),
      optimize_instructions_i64_const(func, dead, rhs_id),
    ) {
    (Some(@lib.I64(raw)), _) if raw == identity => Some(rhs_id)
    (_, Some(@lib.I64(raw))) if raw == identity => Some(lhs_id)
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_identity_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  // A constant identity operand makes these binary ops a no-op. The symmetric
  // cases allow the constant on either side; `sub` is asymmetric because
  // `sub(0, x)` is `-x`, not `x`. `rem(_, 1) -> 0` is asymmetric and requires a
  // pure lhs operand, because folding to the constant would otherwise drop the
  // lhs effect (Binaryen keeps `rem(effect, 1)`).
  match instr {
    @lib.Instruction::I32RemS | @lib.Instruction::I32RemU => {
      let rhs_is_one = match
        optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) => raw == 1
        _ => false
      }
      if rhs_is_one &&
        OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
        return true
      }
    }
    @lib.Instruction::I64RemS | @lib.Instruction::I64RemU => {
      let rhs_is_one = match
        optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) => raw == 1L
        _ => false
      }
      if rhs_is_one &&
        OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i64(
          ctx,
          func,
          node_id,
          @lib.I64(0L),
        )
        return true
      }
    }
    _ => ()
  }
  let keep_id = match instr {
    @lib.Instruction::I32Or
    | @lib.Instruction::I32Xor
    | @lib.Instruction::I32Add
    | @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32ShrS =>
      optimize_instructions_i32_identity_operand(func, dead, lhs_id, rhs_id, 0)
    @lib.Instruction::I32And =>
      optimize_instructions_i32_identity_operand(func, dead, lhs_id, rhs_id, -1)
    @lib.Instruction::I32Mul =>
      optimize_instructions_i32_identity_operand(func, dead, lhs_id, rhs_id, 1)
    @lib.Instruction::I32Sub =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(0)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I32DivS | @lib.Instruction::I32DivU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(1)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I32Rotl | @lib.Instruction::I32Rotr =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(0)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I64Or
    | @lib.Instruction::I64Xor
    | @lib.Instruction::I64Add
    | @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64ShrS =>
      optimize_instructions_i64_identity_operand(func, dead, lhs_id, rhs_id, 0L)
    @lib.Instruction::I64And =>
      optimize_instructions_i64_identity_operand(
        func, dead, lhs_id, rhs_id, -1L,
      )
    @lib.Instruction::I64Mul =>
      optimize_instructions_i64_identity_operand(func, dead, lhs_id, rhs_id, 1L)
    @lib.Instruction::I64Sub =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(0L)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I64DivS | @lib.Instruction::I64DivU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(1L)) => Some(lhs_id)
        _ => None
      }
    @lib.Instruction::I64Rotl | @lib.Instruction::I64Rotr =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(0L)) => Some(lhs_id)
        _ => None
      }
    _ => None
  }
  match keep_id {
    Some(id) => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, id)
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_fold_absorbing_zero_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let zero_on_lhs = match optimize_instructions_i32_const(func, dead, lhs_id) {
    Some(@lib.I32(0)) => true
    _ => false
  }
  let zero_on_rhs = match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(0)) => true
    _ => false
  }
  let pure_other = if zero_on_lhs && !zero_on_rhs {
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, rhs_id)
  } else if zero_on_rhs && !zero_on_lhs {
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id)
  } else if zero_on_lhs && zero_on_rhs {
    true
  } else {
    false
  }
  if pure_other {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(0),
    )
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_fold_absorbing_zero_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let zero_on_lhs = match optimize_instructions_i64_const(func, dead, lhs_id) {
    Some(@lib.I64(0L)) => true
    _ => false
  }
  let zero_on_rhs = match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(0L)) => true
    _ => false
  }
  let pure_other = if zero_on_lhs && !zero_on_rhs {
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, rhs_id)
  } else if zero_on_rhs && !zero_on_lhs {
    OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id)
  } else if zero_on_lhs && zero_on_rhs {
    true
  } else {
    false
  }
  if pure_other {
    optimize_instructions_replace_with_const_i64(
      ctx,
      func,
      node_id,
      @lib.I64(0L),
    )
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_fold_absorbing_neg_one_or_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let neg_one_on_lhs = match
    optimize_instructions_i32_const(func, dead, lhs_id) {
    Some(@lib.I32(-1)) => true
    _ => false
  }
  let neg_one_on_rhs = match
    optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(-1)) => true
    _ => false
  }
  if !neg_one_on_lhs && !neg_one_on_rhs {
    return false
  }
  let effectful_id = if neg_one_on_lhs && !neg_one_on_rhs {
    if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, rhs_id) {
      None
    } else {
      Some(rhs_id)
    }
  } else if neg_one_on_rhs && !neg_one_on_lhs {
    if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
      None
    } else {
      Some(lhs_id)
    }
  } else {
    None
  }
  match effectful_id {
    Some(drop_id) =>
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        drop_id,
        @lib.I32(-1),
      )
    None =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(-1),
      )
  }
  true
}

///|
fn optimize_instructions_try_fold_absorbing_neg_one_or_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let neg_one_on_lhs = match
    optimize_instructions_i64_const(func, dead, lhs_id) {
    Some(@lib.I64(-1L)) => true
    _ => false
  }
  let neg_one_on_rhs = match
    optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(-1L)) => true
    _ => false
  }
  if !neg_one_on_lhs && !neg_one_on_rhs {
    return false
  }
  let effectful_id = if neg_one_on_lhs && !neg_one_on_rhs {
    if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, rhs_id) {
      None
    } else {
      Some(rhs_id)
    }
  } else if neg_one_on_rhs && !neg_one_on_lhs {
    if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
      None
    } else {
      Some(lhs_id)
    }
  } else {
    None
  }
  match effectful_id {
    Some(drop_id) =>
      optimize_instructions_replace_with_drop_then_const_i64(
        ctx,
        func,
        node_id,
        drop_id,
        @lib.I64(-1L),
      )
    None =>
      optimize_instructions_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(-1L),
      )
  }
  true
}

///|
fn optimize_instructions_try_fold_absorbing_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  // A zero-absorbing operand reduces these binops to `0` when the other operand
  // is side-effect-free. Folding would otherwise drop a non-pure lhs/rhs effect
  // (Binaryen keeps e.g. `mul(effect, 0)` and `rem(effect, -1)`).
  match instr {
    @lib.Instruction::I32Mul | @lib.Instruction::I32And =>
      optimize_instructions_try_fold_absorbing_zero_i32(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    @lib.Instruction::I64Mul | @lib.Instruction::I64And =>
      optimize_instructions_try_fold_absorbing_zero_i64(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    @lib.Instruction::I32RemS => {
      let rhs_is_neg_one = match
        optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(-1)) => true
        _ => false
      }
      if rhs_is_neg_one &&
        OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
        true
      } else {
        false
      }
    }
    @lib.Instruction::I64RemS => {
      let rhs_is_neg_one = match
        optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(-1L)) => true
        _ => false
      }
      if rhs_is_neg_one &&
        OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
        optimize_instructions_replace_with_const_i64(
          ctx,
          func,
          node_id,
          @lib.I64(0L),
        )
        true
      } else {
        false
      }
    }
    @lib.Instruction::I32Or =>
      optimize_instructions_try_fold_absorbing_neg_one_or_i32(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    @lib.Instruction::I64Or =>
      optimize_instructions_try_fold_absorbing_neg_one_or_i64(
        ctx, func, dead, node_id, lhs_id, rhs_id,
      )
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_float_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_f32_const(func, dead, rhs_id)) {
    (@lib.Instruction::F32Sub, Some(@lib.F32(raw))) => {
      let replacement_rhs = @ir.hot_build_const_f32(func, @lib.F32(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_add(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(raw))) if raw == 2.0 => {
      let replacement_rhs = @ir.hot_build_const_f32(func, @lib.F32(0.5))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F32Mul, Some(@lib.F32(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f32(func, @lib.F32(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(raw))) if raw == 1.0 => {
      let replacement_rhs = @ir.hot_build_const_f32(func, @lib.F32(1.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F32Div, Some(@lib.F32(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f32(func, @lib.F32(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f32_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    _ => ()
  }
  match (instr, optimize_instructions_f64_const(func, dead, rhs_id)) {
    (@lib.Instruction::F64Sub, Some(@lib.F64(raw))) => {
      let replacement_rhs = @ir.hot_build_const_f64(func, @lib.F64(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_add(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(raw))) if raw == 2.0 => {
      let replacement_rhs = @ir.hot_build_const_f64(func, @lib.F64(0.5))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F64Mul, Some(@lib.F64(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f64(func, @lib.F64(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(raw))) if raw == 1.0 => {
      let replacement_rhs = @ir.hot_build_const_f64(func, @lib.F64(1.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_mul(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    (@lib.Instruction::F64Div, Some(@lib.F64(raw))) if raw == -1.0 => {
      let replacement_lhs = @ir.hot_build_const_f64(func, @lib.F64(-0.0))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::f64_sub(),
        [replacement_lhs, lhs_id],
      )
      return true
    }
    _ => false
  }
}

///|
fn optimize_instructions_wrap_i64_const_to_i32(value : Int64) -> @lib.I32 {
  let lower64 = value & 4294967295L
  if lower64 >= 2147483648L {
    @lib.I32((lower64 - 4294967296L).to_int())
  } else {
    @lib.I32(lower64.to_int())
  }
}

///|
fn optimize_instructions_try_replace_zero_bits_with_zero(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Bool {
  match OiZeroBitsReplacementFact::from_node(func, dead, scratch, node_id) {
    Some(fact) => {
      fact.apply(ctx, func, node_id)
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_fold_convert(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  match
    OiExtendWrapI64MaxBitsFact::from_extend_operand(
      func, dead, scratch, instr, operand_id,
    ) {
    Some(fact) => {
      optimize_instructions_replace_with_node_id(
        ctx,
        func,
        node_id,
        fact.value_id,
      )
      return true
    }
    None => ()
  }
  match (instr, optimize_instructions_i64_const(func, dead, operand_id)) {
    (@lib.Instruction::I32WrapI64, Some(@lib.I64(raw))) => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        optimize_instructions_wrap_i64_const_to_i32(raw),
      )
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_i32_zero_sub_negated_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return None
  }
  match node.op {
    @ir.HotOp::Binary if func.instr_payloads[node.imm0].instr ==
      @lib.Instruction::i32_sub() => {
      let zero_id = func.children[node.child_base]
      let negated_id = func.children[node.child_base + 1]
      if optimize_instructions_i32_const(func, dead, zero_id) ==
        Some(@lib.I32(0)) {
        Some(negated_id)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn optimize_instructions_i64_zero_sub_negated_operand(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 2 {
    return None
  }
  match node.op {
    @ir.HotOp::Binary if func.instr_payloads[node.imm0].instr ==
      @lib.Instruction::i64_sub() => {
      let zero_id = func.children[node.child_base]
      let negated_id = func.children[node.child_base + 1]
      if optimize_instructions_i64_const(func, dead, zero_id) ==
        Some(@lib.I64(0L)) {
        Some(negated_id)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn OiLeadingOperandSwapFact::from_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  a_id : Int,
  b_id : Int,
) -> OiLeadingOperandSwapFact {
  // Binaryen's leading-operand normalization asks `EffectAnalyzer` whether the
  // two operand subtrees may exchange evaluation order. Keep the bounds check
  // and both subtree effect facts as a named proof so callers consume the same
  // OI-G reorder fact instead of a helper-level predicate.
  let effects = pass_require_effects(ctx, func)
  let left_in_bounds = a_id >= 0 && a_id < effects.node_masks.length()
  let right_in_bounds = b_id >= 0 && b_id < effects.node_masks.length()
  let left_effects = if left_in_bounds {
    OiSubtreeReorderEffectFact::from_node(func, effects.node_masks, a_id)
  } else {
    OiSubtreeReorderEffectFact::empty()
  }
  let right_effects = if right_in_bounds {
    OiSubtreeReorderEffectFact::from_node(func, effects.node_masks, b_id)
  } else {
    OiSubtreeReorderEffectFact::empty()
  }
  { left_in_bounds, right_in_bounds, left_effects, right_effects }
}

///|
fn OiLeadingOperandSwapFact::proves_swappable(
  self : OiLeadingOperandSwapFact,
) -> Bool {
  self.left_in_bounds &&
  self.right_in_bounds &&
  self.left_effects.can_swap_with(self.right_effects)
}

///|
fn optimize_instructions_try_remove_redundant_unsigned_mask(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32And => {
      let (mask, value_id) = match
        optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) => (raw, lhs_id)
        None =>
          match optimize_instructions_i32_const(func, dead, lhs_id) {
            Some(@lib.I32(raw)) => (raw, rhs_id)
            None => return false
          }
      }
      if !OiI32LowOnesMaskFact::from_raw(mask).proves_low_ones() {
        return false
      }
      match
        optimize_instructions_i32_unsigned_max(func, dead, scratch, value_id) {
        Some(max_value) if max_value <= mask => {
          optimize_instructions_replace_with_node_id(
            ctx, func, node_id, value_id,
          )
          true
        }
        _ => false
      }
    }
    @lib.Instruction::I64And => {
      let (mask, value_id) = match
        optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) => (raw, lhs_id)
        None =>
          match optimize_instructions_i64_const(func, dead, lhs_id) {
            Some(@lib.I64(raw)) => (raw, rhs_id)
            None => return false
          }
      }
      if !OiI64LowOnesMaskFact::from_raw(mask).proves_low_ones() {
        return false
      }
      match
        optimize_instructions_i64_unsigned_max(func, dead, scratch, value_id) {
        Some(max_value) if max_value <= mask => {
          optimize_instructions_replace_with_node_id(
            ctx, func, node_id, value_id,
          )
          true
        }
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_add_sub(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32Add => {
      let rhs = @ir.hot_node_get(func, rhs_id)
      if rhs.child_count == 2 {
        match rhs.op {
          @ir.HotOp::Binary if func.instr_payloads[rhs.imm0].instr ==
            @lib.Instruction::i32_sub() => {
            let zero_id = func.children[rhs.child_base]
            let sub_rhs_id = func.children[rhs.child_base + 1]
            if optimize_instructions_i32_const(func, dead, zero_id) ==
              Some(@lib.I32(0)) {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i32_sub(),
                [lhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
      let lhs = @ir.hot_node_get(func, lhs_id)
      if lhs.child_count == 2 {
        match lhs.op {
          @ir.HotOp::Binary if func.instr_payloads[lhs.imm0].instr ==
            @lib.Instruction::i32_sub() => {
            let zero_id = func.children[lhs.child_base]
            let sub_rhs_id = func.children[lhs.child_base + 1]
            if optimize_instructions_i32_const(func, dead, zero_id) ==
              Some(@lib.I32(0)) &&
              OiLeadingOperandSwapFact::from_operands(
                ctx, func, rhs_id, sub_rhs_id,
              ).proves_swappable() {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i32_sub(),
                [rhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
    }
    @lib.Instruction::I64Add => {
      let rhs = @ir.hot_node_get(func, rhs_id)
      if rhs.child_count == 2 {
        match rhs.op {
          @ir.HotOp::Binary if func.instr_payloads[rhs.imm0].instr ==
            @lib.Instruction::i64_sub() => {
            let zero_id = func.children[rhs.child_base]
            let sub_rhs_id = func.children[rhs.child_base + 1]
            if optimize_instructions_i64_const(func, dead, zero_id) ==
              Some(@lib.I64(0L)) {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_sub(),
                [lhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
      let lhs = @ir.hot_node_get(func, lhs_id)
      if lhs.child_count == 2 {
        match lhs.op {
          @ir.HotOp::Binary if func.instr_payloads[lhs.imm0].instr ==
            @lib.Instruction::i64_sub() => {
            let zero_id = func.children[lhs.child_base]
            let sub_rhs_id = func.children[lhs.child_base + 1]
            if optimize_instructions_i64_const(func, dead, zero_id) ==
              Some(@lib.I64(0L)) &&
              OiLeadingOperandSwapFact::from_operands(
                ctx, func, rhs_id, sub_rhs_id,
              ).proves_swappable() {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_sub(),
                [rhs_id, sub_rhs_id],
              )
              return true
            }
          }
          _ => ()
        }
      }
    }
    _ => ()
  }
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32Add, Some(@lib.I32(0)))
    | (@lib.Instruction::I32Sub, Some(@lib.I32(0))) => {
      optimize_instructions_replace_with_existing_node(ctx, func, node_id)
      return true
    }
    (@lib.Instruction::I32Add, Some(@lib.I32(raw))) if raw < 0 &&
      !optimize_instructions_prefer_negative_leb_i32(-raw) => {
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i32_sub(),
        [lhs_id, replacement_rhs],
      )
      return true
    }
    _ => ()
  }
  match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
    (@lib.Instruction::I64Add, Some(@lib.I64(0L)))
    | (@lib.Instruction::I64Sub, Some(@lib.I64(0L))) => {
      optimize_instructions_replace_with_existing_node(ctx, func, node_id)
      true
    }
    (@lib.Instruction::I64Add, Some(@lib.I64(raw))) if raw < 0L &&
      !optimize_instructions_prefer_negative_leb_i64(-raw) => {
      let replacement_rhs = @ir.hot_build_const_i64(func, @lib.I64(-raw))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        @lib.Instruction::i64_sub(),
        [lhs_id, replacement_rhs],
      )
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_mul_negation(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32Mul =>
      match
        (
          optimize_instructions_i32_zero_sub_negated_operand(func, dead, lhs_id),
          optimize_instructions_i32_zero_sub_negated_operand(func, dead, rhs_id),
        ) {
        (Some(lhs_negated), Some(rhs_negated)) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_mul(),
            [lhs_negated, rhs_negated],
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64Mul =>
      match
        (
          optimize_instructions_i64_zero_sub_negated_operand(func, dead, lhs_id),
          optimize_instructions_i64_zero_sub_negated_operand(func, dead, rhs_id),
        ) {
        (Some(lhs_negated), Some(rhs_negated)) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i64_mul(),
            [lhs_negated, rhs_negated],
          )
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_try_rewrite_mul_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32Mul, Some(@lib.I32(raw))) =>
      match optimize_instructions_i32_power_of_two_shift(raw) {
        Some(shift) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_shl(),
            [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(shift))],
          )
          true
        }
        None => false
      }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64Mul, Some(@lib.I64(raw))) =>
          match optimize_instructions_i64_power_of_two_shift(raw) {
            Some(shift) => {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_shl(),
                [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(shift))],
              )
              true
            }
            None => false
          }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_rewrite_div_rem_power_of_two(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (instr, optimize_instructions_i32_const(func, dead, rhs_id)) {
    (@lib.Instruction::I32DivU, Some(@lib.I32(raw))) =>
      match optimize_instructions_i32_power_of_two_shift(raw) {
        Some(shift) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_shr_u(),
            [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(shift))],
          )
          true
        }
        None => false
      }
    (@lib.Instruction::I32RemU, Some(@lib.I32(raw))) =>
      match optimize_instructions_i32_power_of_two_shift(raw) {
        Some(_) => {
          optimize_instructions_rewrite_exact_with_children(
            ctx,
            func,
            node_id,
            @lib.Instruction::i32_and(),
            [lhs_id, @ir.hot_build_const_i32(func, @lib.I32(raw - 1))],
          )
          true
        }
        None => false
      }
    _ =>
      match (instr, optimize_instructions_i64_const(func, dead, rhs_id)) {
        (@lib.Instruction::I64DivU, Some(@lib.I64(raw))) =>
          match optimize_instructions_i64_power_of_two_shift(raw) {
            Some(shift) => {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_shr_u(),
                [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(shift))],
              )
              true
            }
            None => false
          }
        (@lib.Instruction::I64RemU, Some(@lib.I64(raw))) =>
          match optimize_instructions_i64_power_of_two_shift(raw) {
            Some(_) => {
              optimize_instructions_rewrite_exact_with_children(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_and(),
                [lhs_id, @ir.hot_build_const_i64(func, @lib.I64(raw - 1L))],
              )
              true
            }
            None => false
          }
        _ => false
      }
  }
}

///|
fn optimize_instructions_required_sign_ext_bits(
  instr : @lib.Instruction,
) -> Int {
  match instr {
    @lib.Instruction::I32Extend8S | @lib.Instruction::I64Extend8S => 8
    @lib.Instruction::I32Extend16S | @lib.Instruction::I64Extend16S => 16
    @lib.Instruction::I64Extend32S => 32
    _ => 0
  }
}

///|
fn optimize_instructions_try_remove_redundant_sign_ext(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  let needed_bits = optimize_instructions_required_sign_ext_bits(instr)
  if needed_bits == 0 {
    return false
  }
  let known_bits = optimize_instructions_sign_ext_bits_for_value(
    func, dead, scratch, operand_id,
  )
  if known_bits != 0 && known_bits <= needed_bits {
    optimize_instructions_replace_with_existing_node(ctx, func, node_id)
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_rewrite_sign_ext_idiom(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let (left_shift_instr, rewrite_instr, shift_amount) = match instr {
    @lib.Instruction::I32ShrS =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(24)) =>
          (@lib.Instruction::i32_shl(), @lib.Instruction::i32_extend8s(), 24)
        Some(@lib.I32(16)) =>
          (@lib.Instruction::i32_shl(), @lib.Instruction::i32_extend16s(), 16)
        _ => return false
      }
    @lib.Instruction::I64ShrS =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(56L)) =>
          (@lib.Instruction::i64_shl(), @lib.Instruction::i64_extend8s(), 56)
        Some(@lib.I64(48L)) =>
          (@lib.Instruction::i64_shl(), @lib.Instruction::i64_extend16s(), 48)
        Some(@lib.I64(32L)) =>
          (@lib.Instruction::i64_shl(), @lib.Instruction::i64_extend32s(), 32)
        _ => return false
      }
    _ => return false
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) {
    return false
  }
  let lhs = @ir.hot_node_get(func, lhs_id)
  match lhs.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if lhs.child_count != 2 {
    return false
  }
  if @ir.hot_node_exact_instr(func, lhs_id) != Some(left_shift_instr) {
    return false
  }
  let lhs_rhs = func.children[lhs.child_base + 1]
  let same_amount = match shift_amount {
    16 | 24 =>
      match optimize_instructions_i32_const(func, dead, lhs_rhs) {
        Some(@lib.I32(raw)) => raw == shift_amount
        _ => false
      }
    _ =>
      match optimize_instructions_i64_const(func, dead, lhs_rhs) {
        Some(@lib.I64(raw)) => raw == shift_amount.to_int64()
        _ => false
      }
  }
  if !same_amount {
    return false
  }
  optimize_instructions_replace_with_exact_unary(
    ctx,
    func,
    node_id,
    rewrite_instr,
    func.children[lhs.child_base],
  )
  true
}

///|
fn optimize_instructions_try_rewrite_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let mask_bits = match optimize_instructions_shift_mask_bits(instr) {
    Some(bits) => bits
    None => return false
  }

  match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => {
      let masked = raw & mask_bits
      if masked == raw {
        return false
      }
      if masked == 0 {
        optimize_instructions_replace_with_existing_node(ctx, func, node_id)
        return true
      }
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(masked))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [lhs_id, replacement_rhs],
      )
      return true
    }
    None => ()
  }

  match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) => {
      let mask64 = mask_bits.to_int64()
      let masked = raw & mask64
      if masked == raw {
        return false
      }
      if masked == 0 {
        optimize_instructions_replace_with_existing_node(ctx, func, node_id)
        return true
      }
      let replacement_rhs = @ir.hot_build_const_i64(func, @lib.I64(masked))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [lhs_id, replacement_rhs],
      )
      return true
    }
    None => ()
  }

  if !OiLiveNodeFact::proves_node_live(func, dead, rhs_id) {
    return false
  }
  let rhs = if rhs_id < func.nodes.length() {
    func.nodes[rhs_id]
  } else {
    @ir.hot_node_get(func, rhs_id)
  }
  let mask_operand_id = match rhs.op {
    @ir.HotOp::Binary =>
      match @ir.hot_node_exact_instr(func, rhs_id) {
        Some(@lib.Instruction::I32And) =>
          match
            optimize_instructions_i32_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I32(raw)) if (raw & mask_bits) == mask_bits =>
              Some(func.children[rhs.child_base])
            _ => None
          }
        Some(@lib.Instruction::I64And) =>
          match
            optimize_instructions_i64_const(
              func,
              dead,
              func.children[rhs.child_base + 1],
            ) {
            Some(@lib.I64(raw)) if (raw & mask_bits.to_int64()) ==
              mask_bits.to_int64() => Some(func.children[rhs.child_base])
            _ => None
          }
        _ => None
      }
    _ => None
  }
  match mask_operand_id {
    Some(masked_operand_id) => {
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [lhs_id, masked_operand_id],
      )
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_combine_nested_const_shift(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let mask_bits = match optimize_instructions_shift_mask_bits(instr) {
    Some(bits) => bits
    None => return false
  }
  if !OiLiveNodeFact::proves_node_live(func, dead, lhs_id) {
    return false
  }
  let inner = @ir.hot_node_get(func, lhs_id)
  match inner.op {
    @ir.HotOp::Binary => ()
    _ => return false
  }
  if inner.child_count != 2 {
    return false
  }
  if @ir.hot_node_exact_instr(func, lhs_id) != Some(instr) {
    return false
  }
  let inner_lhs = func.children[inner.child_base]
  let inner_rhs = func.children[inner.child_base + 1]
  match instr {
    @lib.Instruction::I32Shl
    | @lib.Instruction::I32ShrS
    | @lib.Instruction::I32ShrU
    | @lib.Instruction::I32Rotl
    | @lib.Instruction::I32Rotr => {
      let outer_amount = match
        optimize_instructions_shift_rhs_i32_amount(
          func, dead, rhs_id, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let inner_amount = match
        optimize_instructions_shift_rhs_i32_amount(
          func, dead, inner_rhs, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let combined = (outer_amount + inner_amount) & mask_bits
      let replacement_rhs = @ir.hot_build_const_i32(func, @lib.I32(combined))
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [inner_lhs, replacement_rhs],
      )
      true
    }
    @lib.Instruction::I64Shl
    | @lib.Instruction::I64ShrS
    | @lib.Instruction::I64ShrU
    | @lib.Instruction::I64Rotl
    | @lib.Instruction::I64Rotr => {
      let outer_amount = match
        optimize_instructions_shift_rhs_i64_amount(
          func, dead, rhs_id, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let inner_amount = match
        optimize_instructions_shift_rhs_i64_amount(
          func, dead, inner_rhs, mask_bits,
        ) {
        Some(amount) => amount
        None => return false
      }
      let combined = (outer_amount + inner_amount) & mask_bits
      let replacement_rhs = @ir.hot_build_const_i64(
        func,
        @lib.I64(combined.to_int64()),
      )
      optimize_instructions_rewrite_exact_with_children(
        ctx,
        func,
        node_id,
        instr,
        [inner_lhs, replacement_rhs],
      )
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_compare_zero(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !OiTriviallyPureOperandFact::proves_live_node_pure(func, dead, lhs_id) {
    return false
  }
  match instr {
    @lib.Instruction::I32GeU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw == 0 => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(1),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I32LtU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) if raw == 0 => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(0),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64GeU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) if raw == 0L => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(1),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64LtU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) if raw == 0L => {
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            @lib.I32(0),
          )
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
priv struct OiRemainderInstructionFact {
  live : Bool
  exact_instr : @lib.Instruction?
}

///|
fn OiRemainderInstructionFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiRemainderInstructionFact {
  // Binaryen keeps eq-zero wrappers around integer remainder because remainder
  // may trap. Record Starshine's represented direct/local.tee remainder shape as
  // fact data so compare-to-zero cleanup does not own a bespoke recursive scan.
  let live = OiLiveNodeFact::proves_node_live(func, dead, node_id)
  if !live {
    return { live, exact_instr: None }
  }
  let exact_id = match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, node_id) == 1 =>
      @ir.hot_child_get(func, node_id, 0)
    _ => node_id
  }
  { live, exact_instr: @ir.hot_node_exact_instr(func, exact_id) }
}

///|
fn OiRemainderInstructionFact::proves_remainder(
  self : OiRemainderInstructionFact,
) -> Bool {
  if !self.live {
    return false
  }
  match self.exact_instr {
    Some(
      @lib.Instruction::I32RemS
      | @lib.Instruction::I32RemU
      | @lib.Instruction::I64RemS
      | @lib.Instruction::I64RemU
    ) => true
    _ => false
  }
}

///|
fn OiRemainderInstructionFact::proves_node_remainder(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  OiRemainderInstructionFact::from_node(func, dead, node_id).proves_remainder()
}

///|
fn optimize_instructions_should_keep_i64_eq_zero_if_condition(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I64Eq => ()
    _ => return false
  }
  optimize_instructions_mark_if_condition_nodes(func, dead, scratch)
  if node_id < 0 ||
    node_id >= scratch.if_condition_nodes.length() ||
    !scratch.if_condition_nodes[node_id] {
    return false
  }
  optimize_instructions_i64_const(func, dead, lhs_id) == Some(@lib.I64(0L)) ||
  optimize_instructions_i64_const(func, dead, rhs_id) == Some(@lib.I64(0L))
}

///|
fn optimize_instructions_ref_i31_matches_target(ht : @lib.HeapType) -> Bool {
  match ht {
    @lib.HeapType::AbsHeapTypeHeapType(abs) =>
      abs == @lib.AbsHeapType::i31() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    _ => false
  }
}

///|
fn optimize_instructions_abs_struct_array_matches_target(
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  match (source, target) {
    (
      @lib.HeapType::AbsHeapTypeHeapType(source_abs),
      @lib.HeapType::AbsHeapTypeHeapType(target_abs),
    ) =>
      (
        source_abs == @lib.AbsHeapType::struct_() ||
        source_abs == @lib.AbsHeapType::array()
      ) &&
      (
        target_abs == @lib.AbsHeapType::eq() ||
        target_abs == @lib.AbsHeapType::any()
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_func_matches_target(ht : @lib.HeapType) -> Bool {
  match ht {
    @lib.HeapType::AbsHeapTypeHeapType(abs) => abs == @lib.AbsHeapType::func()
    _ => false
  }
}

///|
fn optimize_instructions_ref_type_heap_matches_target(
  ctx : HotPassContext,
  ref_type : @lib.RefType,
  target : @lib.HeapType,
) -> Bool {
  OiHeapRelationFact::from_heaps(ctx, ref_type.get_heap_type(), target).known_match_target()
}

///|
fn optimize_instructions_ref_i31_cannot_match_target(
  ht : @lib.HeapType,
) -> Bool {
  match ht {
    @lib.HeapType::AbsHeapTypeHeapType(abs) =>
      abs == @lib.AbsHeapType::struct_() || abs == @lib.AbsHeapType::array()
    @lib.HeapType::HeapType(_) | @lib.HeapType::DefTypeHeapType(_) => true
  }
}

///|
fn optimize_instructions_abs_struct_array_disjoint(
  lhs : @lib.HeapType,
  rhs : @lib.HeapType,
) -> Bool {
  match (lhs, rhs) {
    (
      @lib.HeapType::AbsHeapTypeHeapType(lhs_abs),
      @lib.HeapType::AbsHeapTypeHeapType(rhs_abs),
    ) =>
      (
        lhs_abs == @lib.AbsHeapType::struct_() &&
        rhs_abs == @lib.AbsHeapType::array()
      ) ||
      (
        lhs_abs == @lib.AbsHeapType::array() &&
        rhs_abs == @lib.AbsHeapType::struct_()
      )
    _ => false
  }
}

///|
fn optimize_instructions_concrete_comptype_matches_abs(
  comp : @lib.CompType,
  abs : @lib.AbsHeapType,
) -> Bool {
  match comp {
    @lib.StructCompType(_) =>
      abs == @lib.AbsHeapType::struct_() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.ArrayCompType(_) =>
      abs == @lib.AbsHeapType::array() ||
      abs == @lib.AbsHeapType::eq() ||
      abs == @lib.AbsHeapType::any()
    @lib.FuncCompType(_, _) =>
      abs == @lib.AbsHeapType::func() || abs == @lib.AbsHeapType::any()
  }
}

///|
fn optimize_instructions_heap_matches_target(
  module_ctx : @ir.HotModuleContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if source == target {
    return true
  }
  if fuel <= 0 {
    return false
  }
  match (source, target) {
    (
      @lib.HeapType::AbsHeapTypeHeapType(source_abs),
      @lib.HeapType::AbsHeapTypeHeapType(target_abs),
    ) =>
      source_abs == target_abs ||
      (
        source_abs == @lib.AbsHeapType::i31() &&
        optimize_instructions_ref_i31_matches_target(target)
      ) ||
      optimize_instructions_abs_struct_array_matches_target(source, target) ||
      (
        source_abs == @lib.AbsHeapType::eq() &&
        target_abs == @lib.AbsHeapType::any()
      ) ||
      (
        source_abs == @lib.AbsHeapType::func() &&
        target_abs == @lib.AbsHeapType::any()
      )
    (@lib.HeapType::HeapType(source_idx), _) =>
      match @ir.hot_module_resolve_subtype(module_ctx, source_idx) {
        Some(subtype) =>
          optimize_instructions_subtype_heap_matches_target(
            module_ctx,
            subtype,
            target,
            fuel - 1,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_subtype_heap_matches_target(
  module_ctx : @ir.HotModuleContext,
  subtype : @lib.SubType,
  target : @lib.HeapType,
  fuel : Int,
) -> Bool {
  if fuel <= 0 {
    return false
  }
  let (_, supers, comp) = match subtype {
    @lib.CompTypeSubType(_, comp) => (false, [], comp)
    @lib.SubType(is_final, supers, _, comp) => (is_final, supers, comp)
  }
  match target {
    @lib.HeapType::AbsHeapTypeHeapType(abs) =>
      if optimize_instructions_concrete_comptype_matches_abs(comp, abs) {
        return true
      }
    _ => ()
  }
  for super_idx in supers {
    if optimize_instructions_heap_matches_target(
        module_ctx,
        @lib.HeapType::new(super_idx),
        target,
        fuel - 1,
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_replace_ref_cast_with_ref_as_non_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Bool {
  let result_types = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, node_id),
  )
  let temp = @ir.hot_build_heap(
    func,
    result_types,
    @lib.Instruction::ref_as_non_null(),
    [operand_id],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_replace_ref_cast_with_nullref_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Bool {
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let nullref = @lib.ValType::ref_null(none_heap)
  let temp = @ir.hot_build_heap(
    func,
    [nullref],
    @lib.Instruction::ref_cast_type(@lib.RefType::new(true, none_heap)),
    [operand_id],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_narrow_null_cast_boundary_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let label_id = @ir.hot_control_node_label(func, node_id)
  if label_id < 0 || @ir.hot_label_branch_arity(func, label_id) != 1 {
    return false
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(_)] => ()
    _ => return false
  }
  let body = @ir.hot_region_body_ref(func, node_id)
  if @ir.hot_region_root_count(func, body) != 1 {
    return false
  }
  let branch_id = @ir.hot_region_get(func, body, 0)
  let branch = @ir.hot_node_get(func, branch_id)
  if branch.imm0 != label_id || @ir.hot_child_count(func, branch_id) != 1 {
    return false
  }
  let is_cast_branch = match branch.op {
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail => true
    _ => false
  }
  if !is_cast_branch {
    return false
  }
  let guard_id = @ir.hot_child_get(func, branch_id, 0)
  match @ir.hot_node_get(func, guard_id).op {
    @ir.HotOp::RefNull => ()
    _ => return false
  }
  let none_heap = @lib.HeapType::abs(@lib.AbsHeapType::none())
  let nullref = @lib.ValType::ref_null(none_heap)
  let nullref_value_ty = @ir.hot_type_intern_value(func, nullref)
  let nullref_block_ty = @ir.hot_type_intern_block_result(
    func,
    @lib.BlockType::val_type(nullref),
  )
  let target_nullable = match @ir.hot_node_exact_instr(func, branch_id) {
    Some(@lib.Instruction::BrOnCast(_, @lib.CastOp(_, target_nullable), _, _)) =>
      target_nullable
    Some(
      @lib.Instruction::BrOnCastFail(_, @lib.CastOp(_, target_nullable), _, _)
    ) => target_nullable
    _ => return false
  }
  let new_instr = match branch.op {
    @ir.HotOp::BrOnCast =>
      @lib.Instruction::br_on_cast(
        @lib.LabelIdx::new(0U),
        true,
        none_heap,
        target_nullable,
        none_heap,
      )
    @ir.HotOp::BrOnCastFail =>
      @lib.Instruction::br_on_cast_fail(
        @lib.LabelIdx::new(0U),
        true,
        none_heap,
        target_nullable,
        none_heap,
      )
    _ => return false
  }
  let narrowed_guard = @ir.hot_build_ref_null(
    func,
    @lib.RefType::new(true, none_heap),
  )
  let payload_id = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(new_instr),
  )
  let replacement_branch = @ir.hot_build_node(
    func,
    branch.op,
    nullref_value_ty,
    imm0=label_id,
    imm1=payload_id,
    children=[narrowed_guard],
  )
  @ir.hot_replace_node(
    func,
    branch_id,
    @ir.hot_node_get(func, replacement_branch),
  )
  @ir.hot_delete_node(func, replacement_branch)
  @ir.hot_control_result_type_set(func, node_id, nullref_block_ty)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_replace_unreachable_guard_cast_branch(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let guard_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, guard_id).op {
    @ir.HotOp::Unreachable => ()
    _ => return false
  }
  optimize_instructions_replace_with_unreachable(ctx, func, node_id)
  true
}

///|
fn optimize_instructions_try_collapse_dropped_unreachable_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let block_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let body = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body)
  if root_count == 0 {
    return false
  }
  let mut saw_unreachable = false
  for idx = 0; idx < root_count; idx = idx + 1 {
    let root = @ir.hot_region_get(func, body, idx)
    match @ir.hot_node_get(func, root).op {
      @ir.HotOp::Unreachable => {
        saw_unreachable = true
        break
      }
      _ =>
        if !optimize_instructions_node_effects_are_pure(ctx, func, root) {
          return false
        }
    }
  }
  if !saw_unreachable {
    return false
  }
  optimize_instructions_replace_with_unreachable(ctx, func, node_id)
  true
}

///|
fn optimize_instructions_try_fold_ref_test_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let test_fact = match OiRefTestFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return false
  }
  match OiRefTestRewritePlanFact::from_test(ctx, func, test_fact) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_fold_ref_cast_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cast_fact = match OiRefCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return false
  }
  match OiRefCastRewritePlanFact::from_cast(ctx, func, cast_fact) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_skip_ref_cast_desc_eq_exact_success_traps_never_happen(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let success_fact = match
    OiDescriptorExactSuccessFact::from_node(ctx, func, node_id) {
    Some(fact) => fact
    None => return false
  }
  match
    OiDescriptorExactSuccessRewritePlanFact::from_success(ctx, success_fact) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_skip_ref_cast_desc_eq_traps_never_happen(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let skip_fact = match
    OiDescriptorTnhSkipFact::from_node(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return false
  }
  match OiDescriptorTnhSkipRewritePlanFact::from_skip(ctx, func, skip_fact) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_remove_ref_get_desc_child_null_check_traps_never_happen(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  let get_desc_fact = match OiRefGetDescFact::from_node(func, descriptor_id) {
    Some(fact) => fact
    None => return false
  }
  match
    OiRefGetDescNullCheckMoveFact::from_get_desc(
      func,
      get_desc_fact,
      RefGetDescTrapsNeverHappenNullCheckMove,
    ) {
    Some(move_fact) => move_fact.apply(ctx, func, descriptor_id)
    None => false
  }
}

///|
fn optimize_instructions_try_replace_ref_cast_desc_eq_trapping_descriptor_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let null_fact = match
    OiDescriptorNullCastFact::from_node(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return false
  }
  match OiDescriptorNullCastRewritePlanFact::from_null_cast(null_fact, true) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
priv struct OiDescriptorNullableIfNoEffectMoveFact {
  if_root : Bool
  has_three_children : Bool
  condition_side_effect_free : Bool
  has_else : Bool
  single_root_arms : Bool
  then_side_effect_free : Bool
  else_side_effect_free : Bool
  can_move_null_check : Bool
}

///|
fn OiDescriptorNullableIfNoEffectMoveFact::from_if(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorNullableIfNoEffectMoveFact {
  // TNH descriptor operand erasure can drop a nullable `if` child when the
  // condition and both single-result arms are side-effect-free. This preserves
  // the old represented shape as a fact rather than a helper-owned recursive
  // side-effect-free scan.
  let node = @ir.hot_node_get(func, node_id)
  let if_root = match node.op {
    @ir.HotOp::If => true
    _ => false
  }
  if !if_root {
    return {
      if_root,
      has_three_children: false,
      condition_side_effect_free: false,
      has_else: false,
      single_root_arms: false,
      then_side_effect_free: false,
      else_side_effect_free: false,
      can_move_null_check: false,
    }
  }
  let has_three_children = node.child_count == 3
  if !has_three_children {
    return {
      if_root,
      has_three_children,
      condition_side_effect_free: false,
      has_else: false,
      single_root_arms: false,
      then_side_effect_free: false,
      else_side_effect_free: false,
      can_move_null_check: false,
    }
  }
  let condition_side_effect_free = OiSideEffectFreeExpressionFact::proves_node_free(
    func,
    dead,
    @ir.hot_child_get(func, node_id, 0),
  )
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None =>
      return {
        if_root,
        has_three_children,
        condition_side_effect_free,
        has_else: false,
        single_root_arms: false,
        then_side_effect_free: false,
        else_side_effect_free: false,
        can_move_null_check: false,
      }
  }
  let single_root_arms = @ir.hot_region_root_count(func, then_region) == 1 &&
    @ir.hot_region_root_count(func, else_region) == 1
  let then_side_effect_free = single_root_arms &&
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      @ir.hot_region_get(func, then_region, 0),
    )
  let else_side_effect_free = single_root_arms &&
    OiSideEffectFreeExpressionFact::proves_node_free(
      func,
      dead,
      @ir.hot_region_get(func, else_region, 0),
    )
  {
    if_root,
    has_three_children,
    condition_side_effect_free,
    has_else: true,
    single_root_arms,
    then_side_effect_free,
    else_side_effect_free,
    can_move_null_check: has_three_children &&
    condition_side_effect_free &&
    single_root_arms &&
    then_side_effect_free &&
    else_side_effect_free,
  }
}

///|
fn OiDescriptorNullableIfNoEffectMoveFact::proves_can_move_null_check(
  self : OiDescriptorNullableIfNoEffectMoveFact,
) -> Bool {
  self.if_root &&
  self.has_three_children &&
  self.condition_side_effect_free &&
  self.has_else &&
  self.single_root_arms &&
  self.then_side_effect_free &&
  self.else_side_effect_free &&
  self.can_move_null_check
}

///|
priv struct OiDescriptorNullableIfControlMoveFact {
  if_root : Bool
  has_three_children : Bool
  condition_no_escaping_branch_control : Bool
  has_else : Bool
  single_root_arms : Bool
  then_no_escaping_branch_control : Bool
  else_no_escaping_branch_control : Bool
  can_move_null_check : Bool
}

///|
fn OiDescriptorNullableIfControlMoveFact::from_if(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorNullableIfControlMoveFact {
  // Standalone ref.get_desc null-check movement may preserve effectful arms, but
  // only while proving that the condition and both arms have no escaping branch
  // control. Store that Binaryen ChildLocalizer-adjacent boundary explicitly.
  let node = @ir.hot_node_get(func, node_id)
  let if_root = match node.op {
    @ir.HotOp::If => true
    _ => false
  }
  if !if_root {
    return {
      if_root,
      has_three_children: false,
      condition_no_escaping_branch_control: false,
      has_else: false,
      single_root_arms: false,
      then_no_escaping_branch_control: false,
      else_no_escaping_branch_control: false,
      can_move_null_check: false,
    }
  }
  let has_three_children = node.child_count == 3
  if !has_three_children {
    return {
      if_root,
      has_three_children,
      condition_no_escaping_branch_control: false,
      has_else: false,
      single_root_arms: false,
      then_no_escaping_branch_control: false,
      else_no_escaping_branch_control: false,
      can_move_null_check: false,
    }
  }
  let condition_id = @ir.hot_child_get(func, node_id, 0)
  let condition_no_escaping_branch_control = !OiDescriptorBranchControlFact::from_node(
    func, condition_id, condition_id,
  ).proves_has_escaping_branch_control()
  let then_region = @ir.hot_region_then_ref(func, node_id)
  let else_region = match @ir.hot_region_else_ref(func, node_id) {
    Some(region) => region
    None =>
      return {
        if_root,
        has_three_children,
        condition_no_escaping_branch_control,
        has_else: false,
        single_root_arms: false,
        then_no_escaping_branch_control: false,
        else_no_escaping_branch_control: false,
        can_move_null_check: false,
      }
  }
  let single_root_arms = @ir.hot_region_root_count(func, then_region) == 1 &&
    @ir.hot_region_root_count(func, else_region) == 1
  let then_no_escaping_branch_control = single_root_arms &&
    !OiDescriptorBranchControlRegionFact::from_region(
      func, node_id, then_region,
    ).proves_has_escaping_branch_control()
  let else_no_escaping_branch_control = single_root_arms &&
    !OiDescriptorBranchControlRegionFact::from_region(
      func, node_id, else_region,
    ).proves_has_escaping_branch_control()
  {
    if_root,
    has_three_children,
    condition_no_escaping_branch_control,
    has_else: true,
    single_root_arms,
    then_no_escaping_branch_control,
    else_no_escaping_branch_control,
    can_move_null_check: has_three_children &&
    condition_no_escaping_branch_control &&
    single_root_arms &&
    then_no_escaping_branch_control &&
    else_no_escaping_branch_control,
  }
}

///|
fn OiDescriptorNullableIfControlMoveFact::proves_can_move_null_check(
  self : OiDescriptorNullableIfControlMoveFact,
) -> Bool {
  self.if_root &&
  self.has_three_children &&
  self.condition_no_escaping_branch_control &&
  self.has_else &&
  self.single_root_arms &&
  self.then_no_escaping_branch_control &&
  self.else_no_escaping_branch_control &&
  self.can_move_null_check
}

///|
priv struct OiDescriptorBranchControlFact {
  live : Bool
  direct_branch_control : Bool
  nested_branch_control : Bool
  direct_escaping_branch_control : Bool
  nested_escaping_branch_control : Bool
}

///|
priv struct OiDescriptorBranchControlRegionFact {
  root_count : Int
  has_branch_control : Bool
  has_escaping_branch_control : Bool
}

///|
priv struct OiDescriptorSkipOrderFact {
  live : Bool
  direct_order_sensitive_effect : Bool
  region_order_sensitive_effect : Bool
  child_order_sensitive_effect : Bool
}

///|
priv struct OiDescriptorSkipOrderRegionFact {
  root_count : Int
  has_order_sensitive_effect : Bool
}

///|
priv struct OiDescriptorInternalControlEffectFreeFact {
  direct_side_effect_free : Bool
  supported_internal_control_shape : Bool
  block_region_effect_free : Bool
  child_effect_free : Bool
}

///|
priv struct OiDescriptorInternalControlEffectFreeRegionFact {
  root_count : Int
  effect_free : Bool
}

///|
priv struct OiDescriptorContainmentFact {
  root_matches_target : Bool
  live : Bool
  child_contains_target : Bool
  region_contains_target : Bool
}

///|
priv struct OiDescriptorContainmentRegionFact {
  root_count : Int
  contains_target : Bool
}

///|
priv struct OiDescriptorInternalLabelFact {
  label_is_valid : Bool
  owner_contains_label_owner : Bool
}

///|
fn OiDescriptorContainmentFact::empty() -> OiDescriptorContainmentFact {
  {
    root_matches_target: false,
    live: false,
    child_contains_target: false,
    region_contains_target: false,
  }
}

///|
fn OiDescriptorContainmentFact::from_node(
  func : @ir.HotFunc,
  root_id : Int,
  target_id : Int,
) -> OiDescriptorContainmentFact {
  // Descriptor and standalone ref.get_desc control gates need to know whether a
  // branch target's label owner is contained inside the expression being
  // localized. Keep that subtree proof as an explicit fact rather than a helper
  // recursively scanning child and control regions.
  if root_id == target_id {
    return {
      root_matches_target: true,
      live: root_id >= 0 && @ir.hot_node_is_live(func, root_id),
      child_contains_target: false,
      region_contains_target: false,
    }
  }
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return OiDescriptorContainmentFact::empty()
  }
  let node = @ir.hot_node_get(func, root_id)
  let mut child_contains_target = false
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    child_contains_target = child_contains_target ||
      OiDescriptorContainmentFact::from_node(
        func,
        @ir.hot_child_get(func, root_id, slot),
        target_id,
      ).proves_contains_target()
  }
  let region_contains_target = match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      OiDescriptorContainmentRegionFact::from_region(
        func,
        @ir.hot_region_body_ref(func, root_id),
        target_id,
      ).proves_contains_target()
    @ir.HotOp::If => {
      let then_contains = OiDescriptorContainmentRegionFact::from_region(
        func,
        @ir.hot_region_then_ref(func, root_id),
        target_id,
      ).proves_contains_target()
      let else_contains = match @ir.hot_region_else_ref(func, root_id) {
        Some(region_ref) =>
          OiDescriptorContainmentRegionFact::from_region(
            func, region_ref, target_id,
          ).proves_contains_target()
        None => false
      }
      then_contains || else_contains
    }
    _ => false
  }
  {
    root_matches_target: false,
    live: true,
    child_contains_target,
    region_contains_target,
  }
}

///|
fn OiDescriptorContainmentFact::proves_contains_target(
  self : OiDescriptorContainmentFact,
) -> Bool {
  self.root_matches_target ||
  (self.live && (self.child_contains_target || self.region_contains_target))
}

///|
fn OiDescriptorContainmentRegionFact::from_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_id : Int,
) -> OiDescriptorContainmentRegionFact {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut contains_target = false
  for slot = 0; slot < root_count; slot = slot + 1 {
    contains_target = contains_target ||
      OiDescriptorContainmentFact::from_node(
        func,
        @ir.hot_region_get(func, region_ref, slot),
        target_id,
      ).proves_contains_target()
  }
  { root_count, contains_target }
}

///|
fn OiDescriptorContainmentRegionFact::proves_contains_target(
  self : OiDescriptorContainmentRegionFact,
) -> Bool {
  self.root_count > 0 && self.contains_target
}

///|
fn OiDescriptorInternalLabelFact::from_label(
  func : @ir.HotFunc,
  root_id : Int,
  label_id : Int,
) -> OiDescriptorInternalLabelFact {
  if label_id < 0 || label_id >= func.labels.length() {
    return { label_is_valid: false, owner_contains_label_owner: false }
  }
  {
    label_is_valid: true,
    owner_contains_label_owner: OiDescriptorContainmentFact::from_node(
      func,
      root_id,
      @ir.hot_label_owner(func, label_id),
    ).proves_contains_target(),
  }
}

///|
fn OiDescriptorInternalLabelFact::proves_internal(
  self : OiDescriptorInternalLabelFact,
) -> Bool {
  self.label_is_valid && self.owner_contains_label_owner
}

///|
fn OiDescriptorBranchControlFact::empty() -> OiDescriptorBranchControlFact {
  {
    live: false,
    direct_branch_control: false,
    nested_branch_control: false,
    direct_escaping_branch_control: false,
    nested_escaping_branch_control: false,
  }
}

///|
fn OiDescriptorBranchControlFact::from_node(
  func : @ir.HotFunc,
  owner_id : Int,
  node_id : Int,
) -> OiDescriptorBranchControlFact {
  // Binaryen's descriptor/ref-get-desc cleanup uses branch-control and escaping
  // branch-control predicates to decide whether a nullable child can be moved or
  // stripped without swallowing a control transfer. Keep Starshine's represented
  // subtree summary as one fact with explicit direct-branch, nested-branch,
  // direct-escape, and nested-escape fields instead of separate recursive
  // descriptor-control scanners.
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiDescriptorBranchControlFact::empty()
  }
  let node = @ir.hot_node_get(func, node_id)
  let direct_branch_control = match node.op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => true
    _ => false
  }
  let direct_escaping_branch_control = match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf =>
      !OiDescriptorInternalLabelFact::from_label(func, owner_id, node.imm0).proves_internal()
    @ir.HotOp::BrTable =>
      if !OiDescriptorInternalLabelFact::from_label(
          func,
          owner_id,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ).proves_internal() {
        true
      } else {
        let mut escaping = false
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          if !OiDescriptorInternalLabelFact::from_label(
              func, owner_id, label_id,
            ).proves_internal() {
            escaping = true
          }
        }
        escaping
      }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      !OiDescriptorInternalLabelFact::from_label(func, owner_id, node.imm0).proves_internal()
    _ => false
  }
  let mut nested_branch_control = false
  let mut nested_escaping_branch_control = false
  if !direct_branch_control {
    match node.op {
      @ir.HotOp::Block
      | @ir.HotOp::Loop
      | @ir.HotOp::Try
      | @ir.HotOp::TryTable => {
        let body_fact = OiDescriptorBranchControlRegionFact::from_region(
          func,
          owner_id,
          @ir.hot_region_body_ref(func, node_id),
        )
        nested_branch_control = nested_branch_control ||
          body_fact.proves_has_branch_control()
        nested_escaping_branch_control = nested_escaping_branch_control ||
          body_fact.proves_has_escaping_branch_control()
      }
      @ir.HotOp::If => {
        let condition_fact = OiDescriptorBranchControlFact::from_node(
          func,
          owner_id,
          @ir.hot_child_get(func, node_id, 0),
        )
        nested_branch_control = nested_branch_control ||
          condition_fact.proves_has_branch_control()
        nested_escaping_branch_control = nested_escaping_branch_control ||
          condition_fact.proves_has_escaping_branch_control()
        let then_fact = OiDescriptorBranchControlRegionFact::from_region(
          func,
          owner_id,
          @ir.hot_region_then_ref(func, node_id),
        )
        nested_branch_control = nested_branch_control ||
          then_fact.proves_has_branch_control()
        nested_escaping_branch_control = nested_escaping_branch_control ||
          then_fact.proves_has_escaping_branch_control()
        match @ir.hot_region_else_ref(func, node_id) {
          Some(region_ref) => {
            let else_fact = OiDescriptorBranchControlRegionFact::from_region(
              func, owner_id, region_ref,
            )
            nested_branch_control = nested_branch_control ||
              else_fact.proves_has_branch_control()
            nested_escaping_branch_control = nested_escaping_branch_control ||
              else_fact.proves_has_escaping_branch_control()
          }
          None => ()
        }
      }
      _ => ()
    }
  }
  if !direct_escaping_branch_control {
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      let child_fact = OiDescriptorBranchControlFact::from_node(
        func,
        owner_id,
        @ir.hot_child_get(func, node_id, slot),
      )
      nested_branch_control = nested_branch_control ||
        child_fact.proves_has_branch_control()
      nested_escaping_branch_control = nested_escaping_branch_control ||
        child_fact.proves_has_escaping_branch_control()
    }
  }
  {
    live: true,
    direct_branch_control,
    nested_branch_control,
    direct_escaping_branch_control,
    nested_escaping_branch_control,
  }
}

///|
fn OiDescriptorBranchControlFact::proves_has_branch_control(
  self : OiDescriptorBranchControlFact,
) -> Bool {
  self.live && (self.direct_branch_control || self.nested_branch_control)
}

///|
fn OiDescriptorBranchControlFact::proves_has_escaping_branch_control(
  self : OiDescriptorBranchControlFact,
) -> Bool {
  self.live &&
  (self.direct_escaping_branch_control || self.nested_escaping_branch_control)
}

///|
fn OiDescriptorBranchControlRegionFact::from_region(
  func : @ir.HotFunc,
  owner_id : Int,
  region_ref : @ir.HotRegionRef,
) -> OiDescriptorBranchControlRegionFact {
  OiDescriptorBranchControlRegionFact::from_region_range(
    func,
    owner_id,
    region_ref,
    0,
    @ir.hot_region_root_count(func, region_ref),
  )
}

///|
fn OiDescriptorBranchControlRegionFact::from_region_prefix_excluding_tail(
  func : @ir.HotFunc,
  owner_id : Int,
  region_ref : @ir.HotRegionRef,
) -> OiDescriptorBranchControlRegionFact {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count <= 1 {
    return OiDescriptorBranchControlRegionFact::empty()
  }
  OiDescriptorBranchControlRegionFact::from_region_range(
    func,
    owner_id,
    region_ref,
    0,
    root_count - 1,
  )
}

///|
fn OiDescriptorBranchControlRegionFact::from_region_range(
  func : @ir.HotFunc,
  owner_id : Int,
  region_ref : @ir.HotRegionRef,
  start_slot : Int,
  end_slot : Int,
) -> OiDescriptorBranchControlRegionFact {
  let mut has_branch_control = false
  let mut has_escaping_branch_control = false
  let region_root_count = @ir.hot_region_root_count(func, region_ref)
  let end = if end_slot < region_root_count {
    end_slot
  } else {
    region_root_count
  }
  for slot = start_slot; slot < end; slot = slot + 1 {
    let root_fact = OiDescriptorBranchControlFact::from_node(
      func,
      owner_id,
      @ir.hot_region_get(func, region_ref, slot),
    )
    has_branch_control = has_branch_control ||
      root_fact.proves_has_branch_control()
    has_escaping_branch_control = has_escaping_branch_control ||
      root_fact.proves_has_escaping_branch_control()
  }
  {
    root_count: end - start_slot,
    has_branch_control,
    has_escaping_branch_control,
  }
}

///|
fn OiDescriptorBranchControlRegionFact::empty() -> OiDescriptorBranchControlRegionFact {
  {
    root_count: 0,
    has_branch_control: false,
    has_escaping_branch_control: false,
  }
}

///|
fn OiDescriptorBranchControlRegionFact::proves_has_branch_control(
  self : OiDescriptorBranchControlRegionFact,
) -> Bool {
  self.root_count > 0 && self.has_branch_control
}

///|
fn OiDescriptorBranchControlRegionFact::proves_has_escaping_branch_control(
  self : OiDescriptorBranchControlRegionFact,
) -> Bool {
  self.root_count > 0 && self.has_escaping_branch_control
}

///|
fn OiDescriptorSkipOrderFact::empty() -> OiDescriptorSkipOrderFact {
  {
    live: false,
    direct_order_sensitive_effect: false,
    region_order_sensitive_effect: false,
    child_order_sensitive_effect: false,
  }
}

///|
fn OiDescriptorSkipOrderFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorSkipOrderFact {
  // Binaryen's descriptor-cast TNH skip can erase the descriptor immediately
  // only when doing so does not reorder calls, writes, atomics, EH, or other
  // unremovable effects before the reference operand. Keep Starshine's
  // represented order-sensitive subtree summary as a fact instead of a recursive
  // helper-local opcode scan.
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiDescriptorSkipOrderFact::empty()
  }
  let node = @ir.hot_node_get(func, node_id)
  let direct_order_sensitive_effect = match node.op {
    @ir.HotOp::LocalSet
    | @ir.HotOp::LocalTee
    | @ir.HotOp::GlobalSet
    | @ir.HotOp::Store
    | @ir.HotOp::MemoryGrow
    | @ir.HotOp::MemoryCopy
    | @ir.HotOp::MemoryFill
    | @ir.HotOp::MemoryInit
    | @ir.HotOp::DataDrop
    | @ir.HotOp::TableSet
    | @ir.HotOp::TableGrow
    | @ir.HotOp::TableFill
    | @ir.HotOp::TableCopy
    | @ir.HotOp::TableInit
    | @ir.HotOp::ElemDrop
    | @ir.HotOp::Call
    | @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::Atomic
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef => true
    _ => false
  }
  if direct_order_sensitive_effect {
    return {
      live: true,
      direct_order_sensitive_effect,
      region_order_sensitive_effect: false,
      child_order_sensitive_effect: false,
    }
  }
  let region_order_sensitive_effect = match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      OiDescriptorSkipOrderRegionFact::from_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
      ).proves_has_order_sensitive_effect()
    @ir.HotOp::If => {
      let then_effect = OiDescriptorSkipOrderRegionFact::from_region(
        func,
        @ir.hot_region_then_ref(func, node_id),
      ).proves_has_order_sensitive_effect()
      let else_effect = match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          OiDescriptorSkipOrderRegionFact::from_region(func, region_ref).proves_has_order_sensitive_effect()
        None => false
      }
      then_effect || else_effect
    }
    _ => false
  }
  let mut child_order_sensitive_effect = false
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    child_order_sensitive_effect = child_order_sensitive_effect ||
      OiDescriptorSkipOrderFact::from_node(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ).proves_must_preserve_operand_order()
  }
  {
    live: true,
    direct_order_sensitive_effect,
    region_order_sensitive_effect,
    child_order_sensitive_effect,
  }
}

///|
fn OiDescriptorSkipOrderFact::proves_must_preserve_operand_order(
  self : OiDescriptorSkipOrderFact,
) -> Bool {
  self.live &&
  (
    self.direct_order_sensitive_effect ||
    self.region_order_sensitive_effect ||
    self.child_order_sensitive_effect
  )
}

///|
fn OiDescriptorSkipOrderRegionFact::from_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> OiDescriptorSkipOrderRegionFact {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut has_order_sensitive_effect = false
  for slot = 0; slot < root_count; slot = slot + 1 {
    has_order_sensitive_effect = has_order_sensitive_effect ||
      OiDescriptorSkipOrderFact::from_node(
        func,
        @ir.hot_region_get(func, region_ref, slot),
      ).proves_must_preserve_operand_order()
  }
  { root_count, has_order_sensitive_effect }
}

///|
fn OiDescriptorSkipOrderRegionFact::proves_has_order_sensitive_effect(
  self : OiDescriptorSkipOrderRegionFact,
) -> Bool {
  self.root_count > 0 && self.has_order_sensitive_effect
}

///|
fn OiDescriptorInternalControlEffectFreeFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  owner_id : Int,
  node_id : Int,
) -> OiDescriptorInternalControlEffectFreeFact {
  // TNH descriptor-null-check removal can ignore internal branch/control edges
  // when all reachable payload work is otherwise effect-free. Preserve that
  // represented Binaryen `trapOnNull` subset as data: direct side-effect-free
  // proof, an allowed internal-control shell, block-region summaries, and
  // recursively effect-free children.
  let direct_side_effect_free = OiSideEffectFreeExpressionFact::proves_node_free(
    func, dead, node_id,
  )
  if direct_side_effect_free {
    return {
      direct_side_effect_free,
      supported_internal_control_shape: false,
      block_region_effect_free: false,
      child_effect_free: false,
    }
  }
  let node = @ir.hot_node_get(func, node_id)
  let (supported_internal_control_shape, block_region_effect_free) = match
    node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf =>
      (
        OiDescriptorInternalLabelFact::from_label(func, owner_id, node.imm0).proves_internal(),
        true,
      )
    @ir.HotOp::BrTable => {
      let mut labels_internal = OiDescriptorInternalLabelFact::from_label(
        func,
        owner_id,
        @ir.hot_branch_table_default_target(func, node.imm0),
      ).proves_internal()
      if labels_internal {
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          labels_internal = labels_internal &&
            OiDescriptorInternalLabelFact::from_label(func, owner_id, label_id).proves_internal()
        }
      }
      (labels_internal, true)
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      (
        OiDescriptorInternalLabelFact::from_label(func, owner_id, node.imm0).proves_internal(),
        true,
      )
    @ir.HotOp::Block =>
      (
        true,
        OiDescriptorInternalControlEffectFreeRegionFact::from_region(
          func,
          dead,
          owner_id,
          @ir.hot_region_body_ref(func, node_id),
        ).proves_effect_free(),
      )
    @ir.HotOp::Drop => (node.child_count == 1, true)
    _ => (false, false)
  }
  if !supported_internal_control_shape || !block_region_effect_free {
    return {
      direct_side_effect_free,
      supported_internal_control_shape,
      block_region_effect_free,
      child_effect_free: false,
    }
  }
  let mut child_effect_free = true
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    child_effect_free = child_effect_free &&
      OiDescriptorInternalControlEffectFreeFact::from_node(
        func,
        dead,
        owner_id,
        @ir.hot_child_get(func, node_id, slot),
      ).proves_effect_free_allowing_internal_control()
  }
  {
    direct_side_effect_free,
    supported_internal_control_shape,
    block_region_effect_free,
    child_effect_free,
  }
}

///|
fn OiDescriptorInternalControlEffectFreeFact::proves_effect_free_allowing_internal_control(
  self : OiDescriptorInternalControlEffectFreeFact,
) -> Bool {
  self.direct_side_effect_free ||
  (
    self.supported_internal_control_shape &&
    self.block_region_effect_free &&
    self.child_effect_free
  )
}

///|
fn OiDescriptorInternalControlEffectFreeRegionFact::from_region(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  owner_id : Int,
  region_ref : @ir.HotRegionRef,
) -> OiDescriptorInternalControlEffectFreeRegionFact {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut effect_free = true
  for slot = 0; slot < root_count; slot = slot + 1 {
    effect_free = effect_free &&
      OiDescriptorInternalControlEffectFreeFact::from_node(
        func,
        dead,
        owner_id,
        @ir.hot_region_get(func, region_ref, slot),
      ).proves_effect_free_allowing_internal_control()
  }
  { root_count, effect_free }
}

///|
fn OiDescriptorInternalControlEffectFreeRegionFact::proves_effect_free(
  self : OiDescriptorInternalControlEffectFreeRegionFact,
) -> Bool {
  ignore(self.root_count)
  self.effect_free
}

///|
fn optimize_instructions_try_simplify_ref_cast_desc_eq_descriptor_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let simplification_fact = match
    OiDescriptorOperandSimplificationFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return false
  }
  OiDescriptorOperandSimplificationRewritePlanFact::from_fact(
    simplification_fact,
  ).apply(ctx, func, dead, node_id)
}

///|
priv struct OiResultShapeFact {
  live : Bool
  no_results : Bool
  single_ref_result : Bool
  single_nullable_ref_result : Bool
  multivalue_result : Bool
}

///|
fn OiResultShapeFact::empty() -> OiResultShapeFact {
  {
    live: false,
    no_results: false,
    single_ref_result: false,
    single_nullable_ref_result: false,
    multivalue_result: false,
  }
}

///|
fn OiResultShapeFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiResultShapeFact {
  // Binaryen's OI descriptor and standalone ref.get_desc rewrites frequently
  // gate on result arity/nullability before localizing children. Keep those
  // gates as a reusable fact rather than scattered scanner helpers so the
  // represented ChildLocalizer subset can compose with the descriptor facts.
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiResultShapeFact::empty()
  }
  let results = @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))
  let no_results = results.length() == 0
  let single_ref_result = match results {
    [@lib.ValType::RefTypeValType(_)] => true
    _ => false
  }
  let single_nullable_ref_result = match results {
    [@lib.ValType::RefTypeValType(ref_type)] => ref_type.is_nullable()
    _ => false
  }
  {
    live: true,
    no_results,
    single_ref_result,
    single_nullable_ref_result,
    multivalue_result: results.length() > 1,
  }
}

///|
fn OiResultShapeFact::proves_no_results(self : OiResultShapeFact) -> Bool {
  self.live && self.no_results
}

///|
fn OiResultShapeFact::proves_single_ref_result(
  self : OiResultShapeFact,
) -> Bool {
  self.live && self.single_ref_result
}

///|
fn OiResultShapeFact::proves_single_nullable_ref_result(
  self : OiResultShapeFact,
) -> Bool {
  self.live && self.single_nullable_ref_result
}

///|
fn OiResultShapeFact::proves_multivalue_result(
  self : OiResultShapeFact,
) -> Bool {
  self.live && self.multivalue_result
}

///|
priv struct OiStandaloneRefGetDescLeafFact {
  live : Bool
  no_children : Bool
  single_nullable_ref_result : Bool
  known_null_ref_null_leaf : Bool
  nullable_ref_leaf : Bool
  nontrapping_call_operand_leaf : Bool
}

///|
fn OiStandaloneRefGetDescLeafFact::empty() -> OiStandaloneRefGetDescLeafFact {
  {
    live: false,
    no_children: false,
    single_nullable_ref_result: false,
    known_null_ref_null_leaf: false,
    nullable_ref_leaf: false,
    nontrapping_call_operand_leaf: false,
  }
}

///|
fn OiStandaloneRefGetDescLeafFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiStandaloneRefGetDescLeafFact {
  // Binaryen v130's ref.get_desc path delegates to skipNonNullCast and
  // trapOnNull, so Starshine keeps the represented leaf proofs explicit here:
  // ref.null known-null children, nullable local/global leaves that can carry a
  // moved null check, and the nontrapping leaf operands allowed under the
  // current narrow call-child boundary.
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiStandaloneRefGetDescLeafFact::empty()
  }
  let node = @ir.hot_node_get(func, node_id)
  let no_children = @ir.hot_child_count(func, node_id) == 0
  let single_nullable_ref_result = OiResultShapeFact::from_node(func, node_id).proves_single_nullable_ref_result()
  let known_null_ref_null_leaf = match node.op {
    @ir.HotOp::RefNull => no_children && single_nullable_ref_result
    _ => false
  }
  let nullable_ref_leaf = match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::GlobalGet =>
      no_children && single_nullable_ref_result
    _ => false
  }
  let nontrapping_call_operand_leaf = match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => no_children
    _ => false
  }
  {
    live: true,
    no_children,
    single_nullable_ref_result,
    known_null_ref_null_leaf,
    nullable_ref_leaf,
    nontrapping_call_operand_leaf,
  }
}

///|
fn OiStandaloneRefGetDescLeafFact::proves_known_null_ref_null_leaf(
  self : OiStandaloneRefGetDescLeafFact,
) -> Bool {
  ignore(self.no_children)
  ignore(self.single_nullable_ref_result)
  self.live && self.known_null_ref_null_leaf
}

///|
fn OiStandaloneRefGetDescLeafFact::proves_nullable_ref_leaf_can_move_null_check(
  self : OiStandaloneRefGetDescLeafFact,
) -> Bool {
  ignore(self.no_children)
  ignore(self.single_nullable_ref_result)
  self.live && self.nullable_ref_leaf
}

///|
fn OiStandaloneRefGetDescLeafFact::proves_nontrapping_call_operand_leaf(
  self : OiStandaloneRefGetDescLeafFact,
) -> Bool {
  self.live && self.nontrapping_call_operand_leaf
}

///|
priv struct OiStandaloneRefGetDescLocalTeeFact {
  live : Bool
  single_nullable_ref_result : Bool
  single_child : Bool
  child_known_null_ref_null_leaf : Bool
  child_nullable_ref_leaf : Bool
}

///|
fn OiStandaloneRefGetDescLocalTeeFact::empty() -> OiStandaloneRefGetDescLocalTeeFact {
  {
    live: false,
    single_nullable_ref_result: false,
    single_child: false,
    child_known_null_ref_null_leaf: false,
    child_nullable_ref_leaf: false,
  }
}

///|
fn OiStandaloneRefGetDescLocalTeeFact::from_node(
  func : @ir.HotFunc,
  tee_id : Int,
) -> OiStandaloneRefGetDescLocalTeeFact {
  // Represent the two local.tee ref.get_desc boundaries as data: local.tee of a
  // known-null ref.null can be preserved before the trap, while local.tee of a
  // nullable local/global leaf can carry the moved null check.
  if tee_id < 0 || !@ir.hot_node_is_live(func, tee_id) {
    return OiStandaloneRefGetDescLocalTeeFact::empty()
  }
  match @ir.hot_node_get(func, tee_id).op {
    @ir.HotOp::LocalTee => ()
    _ => return OiStandaloneRefGetDescLocalTeeFact::empty()
  }
  let single_nullable_ref_result = OiResultShapeFact::from_node(func, tee_id).proves_single_nullable_ref_result()
  let single_child = @ir.hot_child_count(func, tee_id) == 1
  let child_fact = if single_child {
    OiStandaloneRefGetDescLeafFact::from_node(
      func,
      @ir.hot_child_get(func, tee_id, 0),
    )
  } else {
    OiStandaloneRefGetDescLeafFact::empty()
  }
  {
    live: true,
    single_nullable_ref_result,
    single_child,
    child_known_null_ref_null_leaf: child_fact.proves_known_null_ref_null_leaf(),
    child_nullable_ref_leaf: child_fact.proves_nullable_ref_leaf_can_move_null_check(),
  }
}

///|
fn OiStandaloneRefGetDescLocalTeeFact::proves_known_null_child(
  self : OiStandaloneRefGetDescLocalTeeFact,
) -> Bool {
  self.live &&
  self.single_nullable_ref_result &&
  self.single_child &&
  self.child_known_null_ref_null_leaf
}

///|
fn OiStandaloneRefGetDescLocalTeeFact::proves_can_move_null_check(
  self : OiStandaloneRefGetDescLocalTeeFact,
) -> Bool {
  self.live &&
  self.single_nullable_ref_result &&
  self.single_child &&
  self.child_nullable_ref_leaf
}

///|
priv struct OiStandaloneRefGetDescControlShapeFact {
  live : Bool
  multivalue_result : Bool
  direct_disallowed_control : Bool
  nested_disallowed_control_or_multivalue : Bool
}

///|
fn OiStandaloneRefGetDescControlShapeFact::empty() -> OiStandaloneRefGetDescControlShapeFact {
  {
    live: false,
    multivalue_result: false,
    direct_disallowed_control: false,
    nested_disallowed_control_or_multivalue: false,
  }
}

///|
fn OiStandaloneRefGetDescControlShapeFact::from_node(
  func : @ir.HotFunc,
  owner_id : Int,
  node_id : Int,
) -> OiStandaloneRefGetDescControlShapeFact {
  // Standalone ref.get_desc null-check movement can only preserve a small
  // self-contained control subset. Summarize that represented shape in a fact:
  // multivalue children, disallowed direct control roots, and nested disallowed
  // children. This keeps the compatibility helper from owning a recursive
  // scanner while preserving the previous fail-closed control/EH boundary.
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return OiStandaloneRefGetDescControlShapeFact::empty()
  }
  let multivalue_result = OiResultShapeFact::from_node(func, node_id).proves_multivalue_result()
  if multivalue_result {
    return {
      live: true,
      multivalue_result,
      direct_disallowed_control: false,
      nested_disallowed_control_or_multivalue: false,
    }
  }
  let node = @ir.hot_node_get(func, node_id)
  let direct_disallowed_control = match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf =>
      !OiDescriptorInternalLabelFact::from_label(func, owner_id, node.imm0).proves_internal()
    @ir.HotOp::BrTable => {
      let mut disallowed = !OiDescriptorInternalLabelFact::from_label(
        func,
        owner_id,
        @ir.hot_branch_table_default_target(func, node.imm0),
      ).proves_internal()
      if !disallowed {
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          disallowed = disallowed ||
            !OiDescriptorInternalLabelFact::from_label(func, owner_id, label_id).proves_internal()
        }
      }
      disallowed
    }
    @ir.HotOp::BrOnNonNull =>
      !OiDescriptorInternalLabelFact::from_label(func, owner_id, node.imm0).proves_internal()
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Catch
    | @ir.HotOp::CatchAll => true
    _ => false
  }
  if direct_disallowed_control {
    return {
      live: true,
      multivalue_result,
      direct_disallowed_control,
      nested_disallowed_control_or_multivalue: false,
    }
  }
  let mut nested_disallowed_control_or_multivalue = false
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    nested_disallowed_control_or_multivalue = nested_disallowed_control_or_multivalue ||
      OiStandaloneRefGetDescControlShapeFact::from_node(
        func,
        owner_id,
        @ir.hot_child_get(func, node_id, slot),
      ).proves_disallowed_control_or_multivalue()
  }
  {
    live: true,
    multivalue_result,
    direct_disallowed_control,
    nested_disallowed_control_or_multivalue,
  }
}

///|
fn OiStandaloneRefGetDescControlShapeFact::proves_disallowed_control_or_multivalue(
  self : OiStandaloneRefGetDescControlShapeFact,
) -> Bool {
  self.live &&
  (
    self.multivalue_result ||
    self.direct_disallowed_control ||
    self.nested_disallowed_control_or_multivalue
  )
}

///|
fn optimize_instructions_standalone_ref_get_desc_label_owner_is(
  func : @ir.HotFunc,
  label_id : Int,
  owner_id : Int,
) -> Bool {
  label_id >= 0 &&
  label_id < func.labels.length() &&
  @ir.hot_label_owner(func, label_id) == owner_id
}

///|
priv struct OiStandaloneRefGetDescRootShapeFact {
  live : Bool
  no_results : Bool
  disallowed_control_or_multivalue : Bool
  internal_br_on_non_null_root : Bool
  escaping_br_if_root : Bool
  internal_br_on_cast_root : Bool
  br_on_null_local_root : Bool
  internal_br_on_null_trampoline_root : Bool
}

///|
fn OiStandaloneRefGetDescRootShapeFact::empty() -> OiStandaloneRefGetDescRootShapeFact {
  {
    live: false,
    no_results: false,
    disallowed_control_or_multivalue: false,
    internal_br_on_non_null_root: false,
    escaping_br_if_root: false,
    internal_br_on_cast_root: false,
    br_on_null_local_root: false,
    internal_br_on_null_trampoline_root: false,
  }
}

///|
fn OiStandaloneRefGetDescRootShapeFact::from_root(
  func : @ir.HotFunc,
  block_id : Int,
  root_id : Int,
) -> OiStandaloneRefGetDescRootShapeFact {
  // Standalone ref.get_desc null-check movement accepts only a represented
  // block-root subset: internal br_on_non_null, escaping br_if with safe
  // children, internal br_on_cast/fail over a nullable local, br_on_null local
  // roots, and a tiny br_on_null trampoline block. Keep those root predicates in
  // a fact so callers no longer own parallel root-shape scanners.
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return OiStandaloneRefGetDescRootShapeFact::empty()
  }
  let root = @ir.hot_node_get(func, root_id)
  let no_results = OiResultShapeFact::from_node(func, root_id).proves_no_results()
  let disallowed_control_or_multivalue = OiStandaloneRefGetDescControlShapeFact::from_node(
    func, block_id, root_id,
  ).proves_disallowed_control_or_multivalue()
  let internal_br_on_non_null_root = match root.op {
    @ir.HotOp::BrOnNonNull =>
      OiDescriptorInternalLabelFact::from_label(func, block_id, root.imm0).proves_internal()
    _ => false
  }
  let escaping_br_if_root = match root.op {
    @ir.HotOp::BrIf => {
      let mut child_disallowed = false
      for slot = 0; slot < root.child_count; slot = slot + 1 {
        child_disallowed = child_disallowed ||
          OiStandaloneRefGetDescControlShapeFact::from_node(
            func,
            block_id,
            @ir.hot_child_get(func, root_id, slot),
          ).proves_disallowed_control_or_multivalue()
      }
      !OiDescriptorInternalLabelFact::from_label(func, block_id, root.imm0).proves_internal() &&
      no_results &&
      !child_disallowed
    }
    _ => false
  }
  let internal_br_on_cast_root = match root.op {
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail =>
      if !OiDescriptorInternalLabelFact::from_label(func, block_id, root.imm0).proves_internal() ||
        @ir.hot_child_count(func, root_id) != 1 {
        false
      } else {
        let cast_operands = match @ir.hot_node_exact_instr(func, root_id) {
          Some(
            @lib.Instruction::BrOnCast(
              _,
              @lib.CastOp(src_null, dst_null),
              src_heap,
              dst_heap
            )
          ) => Some((src_null, dst_null, src_heap, dst_heap))
          Some(
            @lib.Instruction::BrOnCastFail(
              _,
              @lib.CastOp(src_null, dst_null),
              src_heap,
              dst_heap
            )
          ) => Some((src_null, dst_null, src_heap, dst_heap))
          _ => None
        }
        match cast_operands {
          Some((source_nullable, target_nullable, source_heap, target_heap)) =>
            if !source_nullable || target_nullable || source_heap != target_heap {
              false
            } else {
              let nullable_ref = @ir.hot_child_get(func, root_id, 0)
              match @ir.hot_node_get(func, nullable_ref).op {
                @ir.HotOp::LocalGet =>
                  match
                    @ir.hot_type_results(
                      func,
                      @ir.hot_node_type(func, nullable_ref),
                    ) {
                    [@lib.ValType::RefTypeValType(ref_type)] =>
                      ref_type.is_nullable() &&
                      ref_type.get_heap_type() == source_heap
                    _ => false
                  }
                _ => false
              }
            }
          None => false
        }
      }
    _ => false
  }
  let br_on_null_local_root = match root.op {
    @ir.HotOp::BrOnNull =>
      optimize_instructions_standalone_ref_get_desc_label_owner_is(
        func,
        root.imm0,
        block_id,
      ) &&
      @ir.hot_child_count(func, root_id) == 1 &&
      (match @ir.hot_node_get(func, @ir.hot_child_get(func, root_id, 0)).op {
        @ir.HotOp::LocalGet =>
          OiResultShapeFact::from_node(
            func,
            @ir.hot_child_get(func, root_id, 0),
          ).proves_single_nullable_ref_result()
        _ => false
      })
    _ => false
  }
  let internal_br_on_null_trampoline_root = match root.op {
    @ir.HotOp::Block =>
      if !no_results {
        false
      } else {
        let inner_label = @ir.hot_control_node_label(func, root_id)
        if !optimize_instructions_standalone_ref_get_desc_label_owner_is(
            func, inner_label, root_id,
          ) ||
          @ir.hot_label_branch_arity(func, inner_label) != 0 {
          false
        } else {
          let body = @ir.hot_region_body_ref(func, root_id)
          let root_count = @ir.hot_region_root_count(func, body)
          if root_count == 1 {
            let branch_id = @ir.hot_region_get(func, body, 0)
            let branch = @ir.hot_node_get(func, branch_id)
            match branch.op {
              @ir.HotOp::Br =>
                optimize_instructions_standalone_ref_get_desc_label_owner_is(
                  func,
                  branch.imm0,
                  block_id,
                ) &&
                @ir.hot_child_count(func, branch_id) == 1 &&
                OiStandaloneRefGetDescRootShapeFact::from_root(
                  func,
                  root_id,
                  @ir.hot_child_get(func, branch_id, 0),
                ).proves_br_on_null_local_root()
              _ => false
            }
          } else if root_count == 2 {
            let null_branch = @ir.hot_region_get(func, body, 0)
            let value_branch = @ir.hot_region_get(func, body, 1)
            if !OiStandaloneRefGetDescRootShapeFact::from_root(
                func, root_id, null_branch,
              ).proves_br_on_null_local_root() {
              false
            } else {
              let branch = @ir.hot_node_get(func, value_branch)
              match branch.op {
                @ir.HotOp::Br =>
                  optimize_instructions_standalone_ref_get_desc_label_owner_is(
                    func,
                    branch.imm0,
                    block_id,
                  ) &&
                  @ir.hot_child_count(func, value_branch) == 0
                _ => false
              }
            }
          } else {
            false
          }
        }
      }
    _ => false
  }
  {
    live: true,
    no_results,
    disallowed_control_or_multivalue,
    internal_br_on_non_null_root,
    escaping_br_if_root,
    internal_br_on_cast_root,
    br_on_null_local_root,
    internal_br_on_null_trampoline_root,
  }
}

///|
fn OiStandaloneRefGetDescRootShapeFact::proves_internal_br_on_non_null_root(
  self : OiStandaloneRefGetDescRootShapeFact,
) -> Bool {
  self.live && self.internal_br_on_non_null_root
}

///|
fn OiStandaloneRefGetDescRootShapeFact::proves_escaping_br_if_root(
  self : OiStandaloneRefGetDescRootShapeFact,
) -> Bool {
  self.live && self.escaping_br_if_root
}

///|
fn OiStandaloneRefGetDescRootShapeFact::proves_internal_br_on_cast_root(
  self : OiStandaloneRefGetDescRootShapeFact,
) -> Bool {
  self.live && self.internal_br_on_cast_root
}

///|
fn OiStandaloneRefGetDescRootShapeFact::proves_br_on_null_local_root(
  self : OiStandaloneRefGetDescRootShapeFact,
) -> Bool {
  self.live && self.br_on_null_local_root
}

///|
fn OiStandaloneRefGetDescRootShapeFact::proves_internal_br_on_null_trampoline_root(
  self : OiStandaloneRefGetDescRootShapeFact,
) -> Bool {
  self.live && self.internal_br_on_null_trampoline_root
}

///|
priv struct OiStandaloneRefGetDescBlockMoveFact {
  live : Bool
  single_nullable_ref_result : Bool
  nonempty_region : Bool
  prefix_roots_allowed : Bool
  saw_internal_ref_branch : Bool
  final_root_allowed : Bool
}

///|
fn OiStandaloneRefGetDescBlockMoveFact::from_block(
  func : @ir.HotFunc,
  block_id : Int,
) -> OiStandaloneRefGetDescBlockMoveFact {
  // This fact is the represented standalone ref.get_desc block-child proof: all
  // prefix roots must be void, free of unsupported nested control/multivalue,
  // or one of the supported branch roots, and the final root must preserve the
  // nullable reference/control handoff shape.
  let empty = {
    live: false,
    single_nullable_ref_result: false,
    nonempty_region: false,
    prefix_roots_allowed: false,
    saw_internal_ref_branch: false,
    final_root_allowed: false,
  }
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return empty
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return empty
  }
  let single_nullable_ref_result = OiResultShapeFact::from_node(func, block_id).proves_single_nullable_ref_result()
  if !single_nullable_ref_result {
    return { ..empty, live: true }
  }
  let body = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body)
  if root_count == 0 {
    return { ..empty, live: true, single_nullable_ref_result }
  }
  let mut prefix_roots_allowed = true
  let mut saw_internal_ref_branch = false
  for slot = 0; slot < root_count - 1; slot = slot + 1 {
    let root_id = @ir.hot_region_get(func, body, slot)
    let root_fact = OiStandaloneRefGetDescRootShapeFact::from_root(
      func, block_id, root_id,
    )
    if !root_fact.no_results {
      prefix_roots_allowed = false
    } else if root_fact.proves_internal_br_on_null_trampoline_root() {
      saw_internal_ref_branch = true
    } else if root_fact.proves_escaping_br_if_root() {
      ()
    } else if root_fact.disallowed_control_or_multivalue {
      prefix_roots_allowed = false
    } else if root_fact.proves_internal_br_on_non_null_root() {
      saw_internal_ref_branch = true
    }
  }
  let final_id = @ir.hot_region_get(func, body, root_count - 1)
  let final_fact = OiStandaloneRefGetDescRootShapeFact::from_root(
    func, block_id, final_id,
  )
  let final_root_allowed = match @ir.hot_node_get(func, final_id).op {
    @ir.HotOp::LocalGet =>
      OiResultShapeFact::from_node(func, final_id).proves_single_nullable_ref_result() &&
      !final_fact.disallowed_control_or_multivalue
    @ir.HotOp::RefNull =>
      saw_internal_ref_branch &&
      OiResultShapeFact::from_node(func, final_id).proves_single_nullable_ref_result() &&
      !final_fact.disallowed_control_or_multivalue
    @ir.HotOp::Br | @ir.HotOp::BrTable =>
      final_fact.no_results && !final_fact.disallowed_control_or_multivalue
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail =>
      final_fact.proves_internal_br_on_cast_root()
    _ => false
  }
  {
    live: true,
    single_nullable_ref_result,
    nonempty_region: true,
    prefix_roots_allowed,
    saw_internal_ref_branch,
    final_root_allowed,
  }
}

///|
fn OiStandaloneRefGetDescBlockMoveFact::proves_can_move_null_check(
  self : OiStandaloneRefGetDescBlockMoveFact,
) -> Bool {
  ignore(self.saw_internal_ref_branch)
  self.live &&
  self.single_nullable_ref_result &&
  self.nonempty_region &&
  self.prefix_roots_allowed &&
  self.final_root_allowed
}

///|
priv struct OiStandaloneRefGetDescKnownNullBlockFact {
  live : Bool
  single_nullable_ref_result : Bool
  nonempty_region : Bool
  branch_free_prefix_roots : Bool
  prefix_roots_void_control_allowed : Bool
  final_known_null_ref_null_leaf : Bool
  final_control_allowed : Bool
}

///|
fn OiStandaloneRefGetDescKnownNullBlockFact::from_block(
  func : @ir.HotFunc,
  block_id : Int,
) -> OiStandaloneRefGetDescKnownNullBlockFact {
  // Known-null standalone ref.get_desc block operands are the previous narrow
  // branch-free block subset expressed as a fact: void/control-safe prefix
  // roots, no branch roots, and a final ref.null leaf with no nested unsupported
  // control or multivalue result.
  let empty = {
    live: false,
    single_nullable_ref_result: false,
    nonempty_region: false,
    branch_free_prefix_roots: false,
    prefix_roots_void_control_allowed: false,
    final_known_null_ref_null_leaf: false,
    final_control_allowed: false,
  }
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return empty
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return empty
  }
  let single_nullable_ref_result = OiResultShapeFact::from_node(func, block_id).proves_single_nullable_ref_result()
  if !single_nullable_ref_result {
    return { ..empty, live: true }
  }
  let body = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body)
  if root_count == 0 {
    return { ..empty, live: true, single_nullable_ref_result }
  }
  let mut branch_free_prefix_roots = true
  let mut prefix_roots_void_control_allowed = true
  for slot = 0; slot < root_count - 1; slot = slot + 1 {
    let root_id = @ir.hot_region_get(func, body, slot)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Br
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrTable
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail => branch_free_prefix_roots = false
      _ => ()
    }
    let control_fact = OiStandaloneRefGetDescControlShapeFact::from_node(
      func, block_id, root_id,
    )
    if !OiResultShapeFact::from_node(func, root_id).proves_no_results() ||
      control_fact.proves_disallowed_control_or_multivalue() {
      prefix_roots_void_control_allowed = false
    }
  }
  let final_id = @ir.hot_region_get(func, body, root_count - 1)
  let final_control_fact = OiStandaloneRefGetDescControlShapeFact::from_node(
    func, block_id, final_id,
  )
  {
    live: true,
    single_nullable_ref_result,
    nonempty_region: true,
    branch_free_prefix_roots,
    prefix_roots_void_control_allowed,
    final_known_null_ref_null_leaf: OiStandaloneRefGetDescLeafFact::from_node(
      func, final_id,
    ).proves_known_null_ref_null_leaf(),
    final_control_allowed: !final_control_fact.proves_disallowed_control_or_multivalue(),
  }
}

///|
fn OiStandaloneRefGetDescKnownNullBlockFact::proves_known_null_child(
  self : OiStandaloneRefGetDescKnownNullBlockFact,
) -> Bool {
  self.live &&
  self.single_nullable_ref_result &&
  self.nonempty_region &&
  self.branch_free_prefix_roots &&
  self.prefix_roots_void_control_allowed &&
  self.final_known_null_ref_null_leaf &&
  self.final_control_allowed
}

///|
priv struct OiStandaloneRefGetDescCallMoveFact {
  live : Bool
  single_ref_result : Bool
  operands_nontrapping_leaves : Bool
}

///|
fn OiStandaloneRefGetDescCallMoveFact::from_call(
  func : @ir.HotFunc,
  call_id : Int,
) -> OiStandaloneRefGetDescCallMoveFact {
  // The current represented call-child movement subset keeps Binaryen's
  // skipNonNullCast idea but only for calls whose operands are simple
  // nontrapping leaves, so moving the ref.as_non_null check across the call
  // operands cannot reorder observable traps or effects.
  let empty = {
    live: false,
    single_ref_result: false,
    operands_nontrapping_leaves: false,
  }
  if call_id < 0 || !@ir.hot_node_is_live(func, call_id) {
    return empty
  }
  match @ir.hot_node_get(func, call_id).op {
    @ir.HotOp::Call | @ir.HotOp::CallIndirect => ()
    _ => return empty
  }
  let single_ref_result = OiResultShapeFact::from_node(func, call_id).proves_single_ref_result()
  if !single_ref_result {
    return { ..empty, live: true }
  }
  let mut operands_nontrapping_leaves = true
  for slot = 0; slot < @ir.hot_child_count(func, call_id); slot = slot + 1 {
    operands_nontrapping_leaves = operands_nontrapping_leaves &&
      OiStandaloneRefGetDescLeafFact::from_node(
        func,
        @ir.hot_child_get(func, call_id, slot),
      ).proves_nontrapping_call_operand_leaf()
  }
  { live: true, single_ref_result, operands_nontrapping_leaves }
}

///|
fn OiStandaloneRefGetDescCallMoveFact::proves_can_move_null_check(
  self : OiStandaloneRefGetDescCallMoveFact,
) -> Bool {
  self.live && self.single_ref_result && self.operands_nontrapping_leaves
}

///|
fn optimize_instructions_try_trap_standalone_ref_get_desc_known_null_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  let get_desc_fact = match OiRefGetDescFact::from_node(func, descriptor_id) {
    Some(fact) => fact
    None => return false
  }
  let null_trap_fact = OiNullTrapFact::for_operand(
    func,
    get_desc_fact.child_id,
    traps_on_null=true,
  )
  if null_trap_fact.can_replace_parent_with_unreachable() {
    optimize_instructions_replace_with_unreachable(ctx, func, descriptor_id)
    return true
  }
  match OiRefGetDescKnownNullChildFact::from_get_desc(func, get_desc_fact) {
    Some(null_child_fact) => null_child_fact.apply(ctx, func, descriptor_id)
    None => false
  }
}

///|
fn optimize_instructions_try_move_standalone_ref_get_desc_null_check(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  let get_desc_fact = match OiRefGetDescFact::from_node(func, descriptor_id) {
    Some(fact) => fact
    None => return false
  }
  if ctx.traps_never_happen {
    let mut is_standalone_root = false
    for root_idx = 0
        root_idx < @ir.hot_root_count(func)
        root_idx = root_idx + 1 {
      if @ir.hot_root_get(func, root_idx) == descriptor_id {
        is_standalone_root = true
        break
      }
    }
    if !is_standalone_root {
      return false
    }
  }
  match
    OiRefGetDescNullCheckMoveFact::from_get_desc(
      func,
      get_desc_fact,
      RefGetDescStandaloneNullCheckMove,
    ) {
    Some(move_fact) => move_fact.apply(ctx, func, descriptor_id)
    None => false
  }
}

///|
fn optimize_instructions_try_move_ref_get_desc_child_null_check(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  let get_desc_fact = match OiRefGetDescFact::from_node(func, descriptor_id) {
    Some(fact) => fact
    None => return false
  }
  match
    OiRefGetDescNullCheckMoveFact::from_get_desc(
      func,
      get_desc_fact,
      RefGetDescDescriptorOperandNullCheckMove,
    ) {
    Some(move_fact) => move_fact.apply(ctx, func, descriptor_id)
    None => false
  }
}

///|
fn optimize_instructions_try_fold_ref_cast_desc_eq_exact_descriptor_miss(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let miss_fact = match
    OiDescriptorExactMissFact::from_node(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return false
  }
  match OiDescriptorExactMissRewritePlanFact::from_miss(ctx, miss_fact) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
fn optimize_instructions_try_narrow_ref_cast_desc_eq_result_type(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let cast_fact = match OiDescriptorCastFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return false
  }
  let narrowing_fact = OiDescriptorResultNarrowingFact::from_cast(
    ctx, func, cast_fact, false,
  )
  match
    OiDescriptorResultNarrowingRewritePlanFact::from_cast_root(narrowing_fact) {
    Some(plan_fact) => return plan_fact.apply(ctx, func, node_id)
    None => ()
  }
  match OiDescriptorCastTighteningFact::from_cast(ctx, func, cast_fact) {
    Some(tightening_fact) =>
      match
        OiDescriptorCastTighteningRewritePlanFact::from_fact(tightening_fact) {
        Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
        None => false
      }
    None => false
  }
}

///|
fn optimize_instructions_try_fold_ref_cast_desc_eq_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let null_fact = match
    OiDescriptorNullCastFact::from_node(ctx, func, dead, node_id) {
    Some(fact) => fact
    None => return false
  }
  match OiDescriptorNullCastRewritePlanFact::from_null_cast(null_fact, false) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
priv struct OiDescriptorAllocationEraseFact {
  live : Bool
  struct_new_default : Bool
  can_erase : Bool
}

///|
fn OiDescriptorAllocationEraseFact::from_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> OiDescriptorAllocationEraseFact {
  // Binaryen v130 can drop allocation-only descriptor operands while replacing
  // descriptor casts/tests with statically-known results. Keep Starshine's
  // represented allocation subset explicit instead of hiding it as a raw
  // instruction whitelist in the descriptor erasure predicate.
  let struct_new_default = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructNewDefault(_)) => true
    _ => false
  }
  { live: true, struct_new_default, can_erase: struct_new_default }
}

///|
fn OiDescriptorAllocationEraseFact::proves_can_erase(
  self : OiDescriptorAllocationEraseFact,
) -> Bool {
  self.live && self.struct_new_default && self.can_erase
}

///|
priv struct OiDescriptorNullableChildEraseTnhFact {
  live : Bool
  side_effect_free : Bool
  block_root : Bool
  block_nonempty : Bool
  block_no_escaping_branch_control : Bool
  block_children_effect_free_internal_control : Bool
  if_root : Bool
  if_can_move_null_check : Bool
  can_erase : Bool
}

///|
fn OiDescriptorNullableChildEraseTnhFact::from_child(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorNullableChildEraseTnhFact {
  // Binaryen v130's traps-never-happen mode may erase a descriptor-side null
  // check when the nullable child can be discarded or localized safely. This is
  // the represented Starshine subset: already side-effect-free children, blocks
  // whose roots are internally-control-safe, and the existing nullable-if
  // movement proof. It is intentionally narrower than full ChildLocalizer and
  // EffectAnalyzer parity.
  let side_effect_free = OiSideEffectFreeExpressionFact::proves_node_free(
    func, dead, node_id,
  )
  let node = @ir.hot_node_get(func, node_id)
  let mut block_root = false
  let mut block_nonempty = false
  let mut block_no_escaping_branch_control = false
  let mut block_children_effect_free_internal_control = false
  let mut if_root = false
  let mut if_can_move_null_check = false
  match node.op {
    @ir.HotOp::Block => {
      block_root = true
      let body = @ir.hot_region_body_ref(func, node_id)
      block_nonempty = @ir.hot_region_root_count(func, body) > 0
      block_no_escaping_branch_control = !OiDescriptorBranchControlFact::from_node(
        func, node_id, node_id,
      ).proves_has_escaping_branch_control()
      block_children_effect_free_internal_control = block_nonempty &&
        block_no_escaping_branch_control
      if block_children_effect_free_internal_control {
        for slot = 0
            slot < @ir.hot_region_root_count(func, body)
            slot = slot + 1 {
          if !OiDescriptorInternalControlEffectFreeFact::from_node(
              func,
              dead,
              node_id,
              @ir.hot_region_get(func, body, slot),
            ).proves_effect_free_allowing_internal_control() {
            block_children_effect_free_internal_control = false
          }
        }
      }
    }
    @ir.HotOp::If => {
      if_root = true
      if_can_move_null_check = OiDescriptorNullableIfNoEffectMoveFact::from_if(
        func, dead, node_id,
      ).proves_can_move_null_check()
    }
    _ => ()
  }
  let can_erase = side_effect_free ||
    (
      block_root &&
      block_nonempty &&
      block_no_escaping_branch_control &&
      block_children_effect_free_internal_control
    ) ||
    (if_root && if_can_move_null_check)
  {
    live: true,
    side_effect_free,
    block_root,
    block_nonempty,
    block_no_escaping_branch_control,
    block_children_effect_free_internal_control,
    if_root,
    if_can_move_null_check,
    can_erase,
  }
}

///|
fn OiDescriptorNullableChildEraseTnhFact::proves_can_erase(
  self : OiDescriptorNullableChildEraseTnhFact,
) -> Bool {
  self.live &&
  self.can_erase &&
  (
    self.side_effect_free ||
    (
      self.block_root &&
      self.block_nonempty &&
      self.block_no_escaping_branch_control &&
      self.block_children_effect_free_internal_control
    ) ||
    (self.if_root && self.if_can_move_null_check)
  )
}

///|
priv struct OiRefGetDescOperandEraseFact {
  live : Bool
  ref_get_desc : Bool
  child_non_nullable_type : Bool
  child_known_non_null : Bool
  child_side_effect_free : Bool
  explicit_nullable_child : Bool
  nullable_child_can_erase_traps_never_happen : Bool
  can_erase_default : Bool
  can_erase_traps_never_happen : Bool
}

///|
fn OiRefGetDescOperandEraseFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiRefGetDescOperandEraseFact {
  // Binaryen v130 descriptor rewrites may drop `ref.get_desc` when the operand
  // is already known non-null and side-effect-free, or when TNH lets the
  // descriptor-side null check be erased. Store both modes as facts so callers
  // do not rescan the wrapper and nullable child independently.
  let get_desc_fact = match OiRefGetDescFact::from_node(func, node_id) {
    Some(fact) => fact
    None =>
      return {
        live: true,
        ref_get_desc: false,
        child_non_nullable_type: false,
        child_known_non_null: false,
        child_side_effect_free: false,
        explicit_nullable_child: false,
        nullable_child_can_erase_traps_never_happen: false,
        can_erase_default: false,
        can_erase_traps_never_happen: false,
      }
  }
  let child_ref_fact = OiRefFact::from_node(func, get_desc_fact.child_id)
  let child_non_nullable_type = child_ref_fact.type_is_non_nullable()
  let child_known_non_null = child_ref_fact.is_known_non_null()
  let child_side_effect_free = OiSideEffectFreeExpressionFact::proves_node_free(
    func,
    dead,
    get_desc_fact.child_id,
  )
  let can_erase_default = (child_non_nullable_type || child_known_non_null) &&
    child_side_effect_free
  let (explicit_nullable_child, nullable_child_can_erase_traps_never_happen) = match
    get_desc_fact.explicit_nullable_child() {
    Some(nullable_child) =>
      (
        true,
        OiDescriptorNullableChildEraseTnhFact::from_child(
          func, dead, nullable_child,
        ).proves_can_erase(),
      )
    None => (false, false)
  }
  {
    live: true,
    ref_get_desc: true,
    child_non_nullable_type,
    child_known_non_null,
    child_side_effect_free,
    explicit_nullable_child,
    nullable_child_can_erase_traps_never_happen,
    can_erase_default,
    can_erase_traps_never_happen: nullable_child_can_erase_traps_never_happen,
  }
}

///|
fn OiRefGetDescOperandEraseFact::proves_default_can_erase(
  self : OiRefGetDescOperandEraseFact,
) -> Bool {
  self.live &&
  self.ref_get_desc &&
  self.can_erase_default &&
  (self.child_non_nullable_type || self.child_known_non_null) &&
  self.child_side_effect_free
}

///|
fn OiRefGetDescOperandEraseFact::proves_tnh_can_erase(
  self : OiRefGetDescOperandEraseFact,
) -> Bool {
  self.live &&
  self.ref_get_desc &&
  self.explicit_nullable_child &&
  self.nullable_child_can_erase_traps_never_happen &&
  self.can_erase_traps_never_happen
}

///|
priv struct OiRefAsNonNullDescriptorOperandEraseTnhFact {
  live : Bool
  ref_as_non_null : Bool
  single_child : Bool
  nullable_child_id : Int
  nullable_child_can_erase_traps_never_happen : Bool
  can_erase : Bool
}

///|
fn OiRefAsNonNullDescriptorOperandEraseTnhFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiRefAsNonNullDescriptorOperandEraseTnhFact {
  // Under TNH, Binaryen's descriptor operand cleanup can erase an explicit
  // `ref.as_non_null` wrapper if the nullable child itself can be discarded or
  // localized. Keep the wrapper arity and child-erasure evidence separate from
  // the top-level descriptor operand predicate.
  let ref_as_non_null = match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefAsNonNull) => true
    _ => false
  }
  let single_child = ref_as_non_null && @ir.hot_child_count(func, node_id) == 1
  let nullable_child_id = if single_child {
    @ir.hot_child_get(func, node_id, 0)
  } else {
    -1
  }
  let nullable_child_can_erase_traps_never_happen = single_child &&
    OiDescriptorNullableChildEraseTnhFact::from_child(
      func, dead, nullable_child_id,
    ).proves_can_erase()
  {
    live: true,
    ref_as_non_null,
    single_child,
    nullable_child_id,
    nullable_child_can_erase_traps_never_happen,
    can_erase: nullable_child_can_erase_traps_never_happen,
  }
}

///|
fn OiRefAsNonNullDescriptorOperandEraseTnhFact::proves_can_erase(
  self : OiRefAsNonNullDescriptorOperandEraseTnhFact,
) -> Bool {
  self.live &&
  self.ref_as_non_null &&
  self.single_child &&
  self.nullable_child_id >= 0 &&
  self.nullable_child_can_erase_traps_never_happen &&
  self.can_erase
}

///|
priv struct OiDescriptorOperandEraseFact {
  live : Bool
  side_effect_free : Bool
  node_effects_pure : Bool
  allocation_can_erase : Bool
  ref_get_desc_can_erase : Bool
  ref_as_non_null_can_erase_traps_never_happen : Bool
  ref_get_desc_can_erase_traps_never_happen : Bool
  can_erase_traps_never_happen : Bool
  can_erase : Bool
}

///|
fn OiDescriptorOperandEraseFact::from_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorOperandEraseFact {
  // Binaryen v130's descriptor-cast/test rewrites use `getDroppedChildren...`,
  // trap-on-null, skipNonNullCast, ChildLocalizer, and EffectAnalyzer to decide
  // whether descriptor operands may disappear. This fact records Starshine's
  // current represented erasure reasons in one source-backed place instead of a
  // helper-local cascade of raw purity, allocation, ref.get_desc, and TNH checks.
  let side_effect_free = OiSideEffectFreeExpressionFact::proves_node_free(
    func, dead, node_id,
  )
  let node_effects_pure = optimize_instructions_node_effects_are_pure(
    ctx, func, node_id,
  )
  let allocation_can_erase = OiDescriptorAllocationEraseFact::from_node(
    func, node_id,
  ).proves_can_erase()
  let ref_get_desc_fact = OiRefGetDescOperandEraseFact::from_node(
    func, dead, node_id,
  )
  let ref_get_desc_can_erase = ref_get_desc_fact.proves_default_can_erase()
  let ref_as_non_null_can_erase_traps_never_happen = OiRefAsNonNullDescriptorOperandEraseTnhFact::from_node(
    func, dead, node_id,
  ).proves_can_erase()
  let ref_get_desc_can_erase_traps_never_happen = ref_get_desc_fact.proves_tnh_can_erase()
  let can_erase_traps_never_happen = ctx.traps_never_happen &&
    (
      ref_as_non_null_can_erase_traps_never_happen ||
      ref_get_desc_can_erase_traps_never_happen
    )
  let can_erase = side_effect_free ||
    node_effects_pure ||
    allocation_can_erase ||
    ref_get_desc_can_erase ||
    can_erase_traps_never_happen
  {
    live: true,
    side_effect_free,
    node_effects_pure,
    allocation_can_erase,
    ref_get_desc_can_erase,
    ref_as_non_null_can_erase_traps_never_happen,
    ref_get_desc_can_erase_traps_never_happen,
    can_erase_traps_never_happen,
    can_erase,
  }
}

///|
fn OiDescriptorOperandEraseFact::proves_can_erase(
  self : OiDescriptorOperandEraseFact,
) -> Bool {
  self.live &&
  self.can_erase &&
  (
    self.side_effect_free ||
    self.node_effects_pure ||
    self.allocation_can_erase ||
    self.ref_get_desc_can_erase ||
    (
      self.can_erase_traps_never_happen &&
      (
        self.ref_as_non_null_can_erase_traps_never_happen ||
        self.ref_get_desc_can_erase_traps_never_happen
      )
    )
  )
}

///|
fn optimize_instructions_defaultable_scratch_type(
  val_type : @lib.ValType,
) -> @lib.ValType? {
  if @lib.has_default(val_type) {
    return Some(val_type)
  }
  match val_type {
    @lib.RefTypeValType(ref_type) =>
      Some(
        @lib.ValType::ref_type(
          @lib.RefType::new(
            true,
            ref_type.get_heap_type(),
            exact=ref_type.is_exact(),
          ),
        ),
      )
    _ => None
  }
}

///|
fn optimize_instructions_defaultable_descriptor_scratch_type(
  val_type : @lib.ValType,
) -> @lib.ValType? {
  match val_type {
    @lib.RefTypeValType(ref_type) =>
      Some(
        @lib.ValType::ref_type(
          @lib.RefType::new(true, ref_type.get_heap_type()),
        ),
      )
    _ => if @lib.has_default(val_type) { Some(val_type) } else { None }
  }
}

///|
fn optimize_instructions_try_replace_ref_get_desc_unreachable_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let get_desc_fact = match OiRefGetDescFact::from_node(func, node_id) {
    Some(fact) => fact
    None => return false
  }
  if get_desc_fact.child_is_unreachable(func) {
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_replace_ref_cast_unreachable_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::Unreachable => {
      optimize_instructions_replace_with_unreachable(ctx, func, node_id)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_remove_ref_as_non_null_local_write_trap_check(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if !ctx.traps_never_happen && !ctx.ignore_implicit_traps {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => return false
  }
  if node.child_count != 1 {
    return false
  }
  let local_type = match @ir.hot_local_type(func, node.imm0) {
    Some(ty) => ty
    None => return false
  }
  let non_null_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_exact_instr(func, non_null_id) {
    Some(@lib.Instruction::RefAsNonNull) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, non_null_id) != 1 {
    return false
  }
  let operand_id = @ir.hot_child_get(func, non_null_id, 0)
  match @ir.hot_type_results(func, @ir.hot_node_type(func, operand_id)) {
    [ty] if ty == local_type => ()
    _ => return false
  }
  @ir.hot_child_set(func, node_id, 0, operand_id)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_try_fold_ref_as_non_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefAsNonNull) => ()
    _ => return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  if OiDescriptorBranchControlFact::from_node(func, operand_id, operand_id).proves_has_branch_control() {
    return false
  }
  if optimize_instructions_try_move_ref_as_non_null_into_ref_cast_desc_eq(
      ctx, func, node_id, operand_id,
    ) {
    return true
  }
  let null_trap_fact = OiNullTrapFact::for_operand(
    func,
    operand_id,
    traps_on_null=true,
  )
  if null_trap_fact.can_replace_parent_with_unreachable() {
    optimize_instructions_replace_with_unreachable(ctx, func, node_id)
    true
  } else if null_trap_fact.can_skip_explicit_non_null_check() {
    optimize_instructions_replace_with_node_id(ctx, func, node_id, operand_id)
    true
  } else {
    false
  }
}

///|
fn optimize_instructions_try_move_ref_as_non_null_into_ref_cast_desc_eq(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  cast_id : Int,
) -> Bool {
  let cast_fact = match OiDescriptorCastFact::from_node(func, cast_id) {
    Some(fact) => fact
    None => return false
  }
  if !cast_fact.nullable {
    optimize_instructions_replace_with_node_id(ctx, func, node_id, cast_id)
    return true
  }
  let narrowing_fact = OiDescriptorResultNarrowingFact::from_cast(
    ctx, func, cast_fact, true,
  )
  match
    OiDescriptorResultNarrowingRewritePlanFact::from_ref_as_non_null_root(
      narrowing_fact,
    ) {
    Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
    None => false
  }
}

///|
priv struct OiRefEqOperandFact {
  same_local : Int?
  same_non_null_local : Int?
  same_non_null_trap_id : Int
  i31_local : Int?
  i31_const : @lib.I32?
  known_non_null_i31 : Bool
  cannot_be_i31 : Bool
  known_null : Bool
  known_non_null : Bool
  local_ref_type : @lib.RefType?
}

///|
fn OiRefEqOperandFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiRefEqOperandFact {
  // Binaryen v130 `visitRefEq` and nearby null/equality rewrites make their
  // decisions from operand shape, local nullability, i31 facts, and disjoint
  // reference heap facts. Keep those facts in one source-backed operand summary
  // instead of spreading same-local, ref.i31, null, and local-heap scanners
  // through the visitor.
  let node = @ir.hot_node_get(func, node_id)
  let local_ref_type = match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) => Some(ref_type)
        _ => None
      }
    _ => None
  }
  let same_local = match node.op {
    @ir.HotOp::LocalGet => Some(node.imm0)
    @ir.HotOp::RefCast =>
      OiRefEqOperandFact::same_local_through_nullable_ref_cast(
        ctx, func, node_id,
      )
    _ => None
  }
  let (same_non_null_local, same_non_null_trap_id) = OiRefEqOperandFact::same_local_through_non_null(
    func, node_id,
  )
  let i31_local = OiRefEqOperandFact::i31_local(func, node_id)
  let i31_const = OiRefEqOperandFact::i31_const(func, dead, node_id)
  let literal_fact = OiRefLiteralFact::from_node(func, node_id)
  let known_non_null_i31 = match node.op {
    @ir.HotOp::LocalGet =>
      match local_ref_type {
        Some(ref_type) =>
          ref_type.is_non_nullable() &&
          ref_type.get_heap_type() ==
          @lib.HeapType::abs(@lib.AbsHeapType::i31())
        None => false
      }
    _ => literal_fact.is_i31()
  }
  let cannot_be_i31 = match local_ref_type {
    Some(ref_type) =>
      OiRefLiteralFact::i31().i31_cannot_match_target(ref_type.get_heap_type())
    None => false
  }
  let known_null = match node.op {
    @ir.HotOp::RefNull => true
    _ =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefNull(_)) => true
        _ => false
      }
  }
  let known_non_null = match node.op {
    @ir.HotOp::LocalGet =>
      match local_ref_type {
        Some(ref_type) => ref_type.is_non_nullable()
        None => false
      }
    _ => literal_fact.is_known_non_null()
  }
  {
    same_local,
    same_non_null_local,
    same_non_null_trap_id,
    i31_local,
    i31_const,
    known_non_null_i31,
    cannot_be_i31,
    known_null,
    known_non_null,
    local_ref_type,
  }
}

///|
fn OiRefEqOperandFact::same_local_through_nullable_ref_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefCast(true, _, target)) => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match @ir.hot_node_get(func, child_id).op {
        @ir.HotOp::LocalGet => {
          let local_idx = @ir.hot_node_get(func, child_id).imm0
          match @ir.hot_local_type(func, local_idx) {
            Some(@lib.ValType::RefTypeValType(ref_type)) =>
              if ctx.ignore_implicit_traps || ctx.traps_never_happen {
                Some(local_idx)
              } else if OiHeapRelationFact::from_heaps(
                  ctx,
                  ref_type.get_heap_type(),
                  target,
                ).known_match_without_full_subtyping() {
                Some(local_idx)
              } else {
                None
              }
            _ => None
          }
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn OiRefEqOperandFact::same_local_through_non_null(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int?, Int) {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet => (Some(@ir.hot_node_get(func, node_id).imm0), -1)
    _ =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefAsNonNull) => {
          if @ir.hot_child_count(func, node_id) != 1 {
            return (None, -1)
          }
          let child_id = @ir.hot_child_get(func, node_id, 0)
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::LocalGet => {
              let local_idx = @ir.hot_node_get(func, child_id).imm0
              match @ir.hot_local_type(func, local_idx) {
                Some(@lib.ValType::RefTypeValType(ref_type)) =>
                  if ref_type.is_non_nullable() {
                    (Some(local_idx), -1)
                  } else {
                    (Some(local_idx), node_id)
                  }
                _ => (None, -1)
              }
            }
            _ => (None, -1)
          }
        }
        _ => (None, -1)
      }
  }
}

///|
fn OiRefEqOperandFact::i31_local(func : @ir.HotFunc, node_id : Int) -> Int? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefI31) => {
      let child_id = @ir.hot_child_get(func, node_id, 0)
      match @ir.hot_node_get(func, child_id).op {
        @ir.HotOp::LocalGet => Some(@ir.hot_node_get(func, child_id).imm0)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn OiRefEqOperandFact::i31_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> @lib.I32? {
  if @ir.hot_child_count(func, node_id) != 1 {
    return None
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefI31) =>
      optimize_instructions_i32_const(
        func,
        dead,
        @ir.hot_child_get(func, node_id, 0),
      )
    _ => None
  }
}

///|
priv struct OiRefEqSkipCastOperandFact {
  replacement_id : Int
  changed : Bool
}

///|
fn OiRefEqSkipCastOperandFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> OiRefEqSkipCastOperandFact {
  // Binaryen v130 `visitRefEq` calls `skipCast(input, (ref null eq))` only
  // under traps-never-happen. Keep the required-type check with the skip fact:
  // an operand wrapper is removable only when its child is already a nullable-eq
  // subtype, so removing the cast cannot make the resulting `ref.eq` invalid.
  if !ctx.traps_never_happen {
    return { replacement_id: node_id, changed: false }
  }
  let mut current_id = node_id
  let mut changed = false
  while current_id >= 0 && @ir.hot_node_is_live(func, current_id) {
    let child_id = match @ir.hot_node_get(func, current_id).op {
      @ir.HotOp::RefCast if @ir.hot_child_count(func, current_id) == 1 =>
        @ir.hot_child_get(func, current_id, 0)
      @ir.HotOp::Heap if @ir.hot_child_count(func, current_id) == 1 =>
        match @ir.hot_node_exact_instr(func, current_id) {
          Some(@lib.Instruction::RefAsNonNull) =>
            @ir.hot_child_get(func, current_id, 0)
          _ => -1
        }
      _ => -1
    }
    if child_id < 0 ||
      !OiRefEqSkipCastOperandFact::node_satisfies_nullable_eq_requirement(
        ctx, func, child_id,
      ) {
      break
    }
    current_id = child_id
    changed = true
  }
  { replacement_id: current_id, changed }
}

///|
fn OiRefEqSkipCastOperandFact::node_satisfies_nullable_eq_requirement(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let ref_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => ref_type
    _ => return false
  }
  OiHeapRelationFact::from_heaps(
    ctx,
    ref_type.get_heap_type(),
    @lib.HeapType::abs(@lib.AbsHeapType::eq()),
  ).known_match_target()
}

///|
priv struct OiRefEqSkipCastFact {
  lhs_replacement_id : Int
  rhs_replacement_id : Int
  changed : Bool
}

///|
fn OiRefEqSkipCastFact::from_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> OiRefEqSkipCastFact {
  let lhs = OiRefEqSkipCastOperandFact::from_node(ctx, func, lhs_id)
  let rhs = OiRefEqSkipCastOperandFact::from_node(ctx, func, rhs_id)
  {
    lhs_replacement_id: lhs.replacement_id,
    rhs_replacement_id: rhs.replacement_id,
    changed: lhs.changed || rhs.changed,
  }
}

///|
fn OiRefEqSkipCastFact::apply(
  self : OiRefEqSkipCastFact,
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if !self.changed {
    return false
  }
  @ir.hot_child_set(func, node_id, 0, self.lhs_replacement_id)
  @ir.hot_child_set(func, node_id, 1, self.rhs_replacement_id)
  pass_mark_mutated(ctx, func)
  true
}

///|
priv struct OiRefEqRelationFact {
  lhs : OiRefEqOperandFact
  rhs : OiRefEqOperandFact
}

///|
fn OiRefEqRelationFact::from_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> OiRefEqRelationFact {
  {
    lhs: OiRefEqOperandFact::from_node(ctx, func, dead, lhs_id),
    rhs: OiRefEqOperandFact::from_node(ctx, func, dead, rhs_id),
  }
}

///|
fn OiRefEqRelationFact::proves_equal(self : OiRefEqRelationFact) -> Bool {
  match (self.lhs.same_local, self.rhs.same_local) {
    (Some(lhs), Some(rhs)) if lhs == rhs => return true
    _ => ()
  }
  match (self.lhs.i31_local, self.rhs.i31_local) {
    (Some(lhs), Some(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn OiRefEqRelationFact::same_local_non_null_trap(
  self : OiRefEqRelationFact,
) -> Int? {
  match (self.lhs.same_non_null_local, self.rhs.same_non_null_local) {
    (Some(lhs), Some(rhs)) if lhs == rhs =>
      if self.lhs.same_non_null_trap_id >= 0 {
        Some(self.lhs.same_non_null_trap_id)
      } else if self.rhs.same_non_null_trap_id >= 0 {
        Some(self.rhs.same_non_null_trap_id)
      } else {
        None
      }
    _ => None
  }
}

///|
fn OiRefEqRelationFact::i31_const_result(
  self : OiRefEqRelationFact,
) -> @lib.I32? {
  match (self.lhs.i31_const, self.rhs.i31_const) {
    (Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) =>
      Some(if lhs == rhs { @lib.I32(1) } else { @lib.I32(0) })
    _ => None
  }
}

///|
fn OiRefEqRelationFact::proves_impossible_equal(
  self : OiRefEqRelationFact,
  ctx : HotPassContext,
) -> Bool {
  if (self.lhs.known_non_null_i31 && self.rhs.cannot_be_i31) ||
    (self.rhs.known_non_null_i31 && self.lhs.cannot_be_i31) {
    return true
  }
  match (self.lhs.local_ref_type, self.rhs.local_ref_type) {
    (Some(lhs), Some(rhs)) =>
      (lhs.is_non_nullable() || rhs.is_non_nullable()) &&
      OiHeapRelationFact::from_heaps(
        ctx,
        lhs.get_heap_type(),
        rhs.get_heap_type(),
      ).known_abs_struct_array_disjoint()
    _ => false
  }
}

///|
fn optimize_instructions_replace_with_drop_then_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
  value : @lib.I32,
) -> Unit {
  let temp = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [@ir.hot_build_drop(func, drop_id), @ir.hot_build_const_i32(func, value)],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_drop_then_const_i64(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
  value : @lib.I64,
) -> Unit {
  let temp = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i64()),
    [@ir.hot_build_drop(func, drop_id), @ir.hot_build_const_i64(func, value)],
  )
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
}

///|
fn optimize_instructions_replace_with_drop_then_node_id(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
  value_id : Int,
) -> Bool {
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let temp = @ir.hot_build_block(func, block_type, [
    @ir.hot_build_drop(func, drop_id),
    value_id,
  ])
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_replace_with_local_set_then_node_id(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  localize_id : Int,
  value_id : Int,
) -> Bool {
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let local_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, localize_id)) {
    [val_type] =>
      match
        optimize_instructions_defaultable_descriptor_scratch_type(val_type) {
        Some(local_type) => local_type
        None => return false
      }
    _ => return false
  }
  let local_id = @ir.hot_append_body_local(func, local_type)
  let temp = @ir.hot_build_block(func, block_type, [
    @ir.hot_build_local_set(func, local_id, localize_id),
    value_id,
  ])
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_restore_localized_result(
  func : @ir.HotFunc,
  local_get : Int,
  local_type : @lib.ValType,
  result_type : @lib.ValType,
) -> Int? {
  if local_type == result_type {
    return Some(local_get)
  }
  match (local_type, result_type) {
    (
      @lib.ValType::RefTypeValType(local_ref),
      @lib.ValType::RefTypeValType(result_ref),
    ) if local_ref.is_nullable() &&
      result_ref.is_non_nullable() &&
      local_ref.get_heap_type() == result_ref.get_heap_type() &&
      local_ref.is_exact() == result_ref.is_exact() =>
      Some(
        @ir.hot_build_heap(
          func,
          [result_type],
          @lib.Instruction::ref_as_non_null(),
          [local_get],
        ),
      )
    _ => None
  }
}

///|
fn optimize_instructions_replace_with_localized_node_then_descriptor_then_local_get(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value_id : Int,
  descriptor_id : Int,
) -> Bool {
  let result_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [val_type] => val_type
    _ => return false
  }
  let value_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, value_id)) {
    [val_type] => val_type
    _ => return false
  }
  let local_type = match
    optimize_instructions_defaultable_scratch_type(value_type) {
    Some(local_type) => local_type
    None => return false
  }
  let local_id = @ir.hot_append_body_local(func, local_type)
  let local_get = @ir.hot_build_local_get(func, local_id)
  let result_id = match
    optimize_instructions_restore_localized_result(
      func, local_get, local_type, result_type,
    ) {
    Some(result_id) => result_id
    None => return false
  }
  let descriptor_eval = if OiDescriptorOperandSkipLocalizationFact::from_operand(
      func, descriptor_id,
    ).proves_should_localize_when_skipped() {
    let descriptor_type = match
      @ir.hot_type_results(func, @ir.hot_node_type(func, descriptor_id)) {
      [val_type] =>
        match
          optimize_instructions_defaultable_descriptor_scratch_type(val_type) {
          Some(local_type) => local_type
          None => return false
        }
      _ => return false
    }
    let descriptor_local_id = @ir.hot_append_body_local(func, descriptor_type)
    @ir.hot_build_local_set(func, descriptor_local_id, descriptor_id)
  } else {
    @ir.hot_build_drop(func, descriptor_id)
  }
  let temp = @ir.hot_build_block(func, @lib.BlockType::val_type(result_type), [
    @ir.hot_build_local_set(func, local_id, value_id),
    descriptor_eval,
    result_id,
  ])
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_replace_with_drop_then_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  drop_id : Int,
) -> Bool {
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let temp = @ir.hot_build_block(func, block_type, [
    @ir.hot_build_drop(func, drop_id),
    @ir.hot_build_unreachable(func),
  ])
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_replace_with_drop_drop_then_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  first_drop_id : Int,
  second_drop_id : Int,
) -> Bool {
  let block_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [] => @lib.BlockType::void_()
    [val_type] => @lib.BlockType::val_type(val_type)
    _ => return false
  }
  let temp = @ir.hot_build_block(func, block_type, [
    @ir.hot_build_drop(func, first_drop_id),
    @ir.hot_build_drop(func, second_drop_id),
    @ir.hot_build_unreachable(func),
  ])
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_replace_node(func, node_id, replacement)
  @ir.hot_label_owner_set(
    func,
    @ir.hot_control_node_label(func, node_id),
    node_id,
  )
  @ir.hot_delete_node(func, temp)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_node_effects_are_pure(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let effects = pass_require_effects(ctx, func)
  OiNodeEffectPurityFact::from_node_masks(effects.node_masks, node_id).proves_pure()
}

///|
fn optimize_instructions_replace_ref_eq_impossible_with_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  lhs_id : Int,
  rhs_id : Int,
) -> Unit {
  let lhs_pure = optimize_instructions_node_effects_are_pure(ctx, func, lhs_id)
  let rhs_pure = optimize_instructions_node_effects_are_pure(ctx, func, rhs_id)
  match (lhs_pure, rhs_pure) {
    (true, true) =>
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(0),
      )
    (false, true) =>
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        lhs_id,
        @lib.I32(0),
      )
    (true, false) =>
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        rhs_id,
        @lib.I32(0),
      )
    (false, false) => {
      let temp = @ir.hot_build_block(
        func,
        @lib.BlockType::val_type(@lib.ValType::i32()),
        [
          @ir.hot_build_drop(func, lhs_id),
          @ir.hot_build_drop(func, rhs_id),
          @ir.hot_build_const_i32(func, @lib.I32(0)),
        ],
      )
      let replacement = @ir.hot_node_get(func, temp)
      @ir.hot_replace_node(func, node_id, replacement)
      @ir.hot_label_owner_set(
        func,
        @ir.hot_control_node_label(func, node_id),
        node_id,
      )
      @ir.hot_delete_node(func, temp)
      pass_mark_mutated(ctx, func)
    }
  }
}

///|
fn optimize_instructions_try_rewrite_ref_eq_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 2 {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefEq) => ()
    _ => return false
  }
  let mut lhs_id = @ir.hot_child_get(func, node_id, 0)
  let mut rhs_id = @ir.hot_child_get(func, node_id, 1)
  let mut relation_fact = OiRefEqRelationFact::from_operands(
    ctx, func, dead, lhs_id, rhs_id,
  )
  if relation_fact.proves_equal() {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(1),
    )
    return true
  }
  match relation_fact.same_local_non_null_trap() {
    Some(trap_id) => {
      optimize_instructions_replace_with_drop_then_const_i32(
        ctx,
        func,
        node_id,
        trap_id,
        @lib.I32(1),
      )
      return true
    }
    _ => ()
  }
  match relation_fact.i31_const_result() {
    Some(result) => {
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      return true
    }
    _ => ()
  }
  if relation_fact.proves_impossible_equal(ctx) {
    optimize_instructions_replace_ref_eq_impossible_with_const_i32(
      ctx, func, node_id, lhs_id, rhs_id,
    )
    return true
  }
  let skip_cast_fact = OiRefEqSkipCastFact::from_operands(
    ctx, func, lhs_id, rhs_id,
  )
  let skipped_cast = skip_cast_fact.apply(ctx, func, node_id)
  if skipped_cast {
    lhs_id = skip_cast_fact.lhs_replacement_id
    rhs_id = skip_cast_fact.rhs_replacement_id
    relation_fact = OiRefEqRelationFact::from_operands(
      ctx, func, dead, lhs_id, rhs_id,
    )
    if relation_fact.proves_equal() {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(1),
      )
      return true
    }
    match relation_fact.same_local_non_null_trap() {
      Some(trap_id) => {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          trap_id,
          @lib.I32(1),
        )
        return true
      }
      _ => ()
    }
    match relation_fact.i31_const_result() {
      Some(result) => {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
        return true
      }
      _ => ()
    }
  }
  if relation_fact.lhs.known_null && relation_fact.rhs.known_null {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(1),
    )
    return true
  }
  if relation_fact.lhs.known_null {
    if relation_fact.rhs.known_non_null {
      if optimize_instructions_node_effects_are_pure(ctx, func, rhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          rhs_id,
          @lib.I32(0),
        )
      }
    } else {
      OiRefIsNullRewritePlanFact::replace_node_with_ref_is_null(
        ctx, func, node_id, rhs_id,
      )
    }
    return true
  }
  if relation_fact.rhs.known_null {
    if relation_fact.lhs.known_non_null {
      if optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(
          ctx,
          func,
          node_id,
          @lib.I32(0),
        )
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx,
          func,
          node_id,
          lhs_id,
          @lib.I32(0),
        )
      }
    } else {
      OiRefIsNullRewritePlanFact::replace_node_with_ref_is_null(
        ctx, func, node_id, lhs_id,
      )
    }
    return true
  }
  skipped_cast
}

///|
fn optimize_instructions_same_local_integer_compare_result(
  instr : @lib.Instruction,
) -> @lib.I32? {
  match instr {
    @lib.Instruction::I32Eq | @lib.Instruction::I64Eq => Some(@lib.I32(1))
    @lib.Instruction::I32Ne
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I32LtS
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I64LtS
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GtU => Some(@lib.I32(0))
    @lib.Instruction::I32LeS
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64GeU => Some(@lib.I32(1))
    _ => None
  }
}

///|
fn optimize_instructions_bool_i32(value : Bool) -> @lib.I32 {
  if value {
    @lib.I32(1)
  } else {
    @lib.I32(0)
  }
}

///|
fn optimize_instructions_try_fold_integer_const_eq_ne_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match instr {
    @lib.Instruction::I32Eq
    | @lib.Instruction::I32Ne
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I32GeU =>
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I32(lhs_raw)), Some(@lib.I32(rhs_raw))) => {
          match instr {
            @lib.Instruction::I32Eq | @lib.Instruction::I32Ne if lhs_raw >
              rhs_raw => return false
            _ => ()
          }
          let result = match instr {
            @lib.Instruction::I32Eq => lhs_raw == rhs_raw
            @lib.Instruction::I32Ne => lhs_raw != rhs_raw
            @lib.Instruction::I32LtU =>
              lhs_raw.reinterpret_as_uint() < rhs_raw.reinterpret_as_uint()
            @lib.Instruction::I32LeU =>
              lhs_raw.reinterpret_as_uint() <= rhs_raw.reinterpret_as_uint()
            @lib.Instruction::I32GtU =>
              lhs_raw.reinterpret_as_uint() > rhs_raw.reinterpret_as_uint()
            @lib.Instruction::I32GeU =>
              lhs_raw.reinterpret_as_uint() >= rhs_raw.reinterpret_as_uint()
            _ => false
          }
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            optimize_instructions_bool_i32(result),
          )
          true
        }
        _ => false
      }
    @lib.Instruction::I64Eq
    | @lib.Instruction::I64Ne
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I64GtU
    | @lib.Instruction::I64GeU =>
      match
        (
          optimize_instructions_i64_const(func, dead, lhs_id),
          optimize_instructions_i64_const(func, dead, rhs_id),
        ) {
        (Some(@lib.I64(lhs_raw)), Some(@lib.I64(rhs_raw))) => {
          match instr {
            @lib.Instruction::I64Eq | @lib.Instruction::I64Ne if lhs_raw >
              rhs_raw => return false
            _ => ()
          }
          let result = match instr {
            @lib.Instruction::I64Eq => lhs_raw == rhs_raw
            @lib.Instruction::I64Ne => lhs_raw != rhs_raw
            @lib.Instruction::I64LtU =>
              lhs_raw.reinterpret_as_uint64() < rhs_raw.reinterpret_as_uint64()
            @lib.Instruction::I64LeU =>
              lhs_raw.reinterpret_as_uint64() <= rhs_raw.reinterpret_as_uint64()
            @lib.Instruction::I64GtU =>
              lhs_raw.reinterpret_as_uint64() > rhs_raw.reinterpret_as_uint64()
            @lib.Instruction::I64GeU =>
              lhs_raw.reinterpret_as_uint64() >= rhs_raw.reinterpret_as_uint64()
            _ => false
          }
          optimize_instructions_replace_with_const_i32(
            ctx,
            func,
            node_id,
            optimize_instructions_bool_i32(result),
          )
          true
        }
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_unsigned_domain_edge_compare_result(
  instr : @lib.Instruction,
  rhs_is_zero : Bool,
  rhs_is_unsigned_max : Bool,
) -> @lib.I32? {
  if rhs_is_zero {
    match instr {
      @lib.Instruction::I32LtU | @lib.Instruction::I64LtU => Some(@lib.I32(0))
      @lib.Instruction::I32GeU | @lib.Instruction::I64GeU => Some(@lib.I32(1))
      _ => None
    }
  } else if rhs_is_unsigned_max {
    match instr {
      @lib.Instruction::I32GtU | @lib.Instruction::I64GtU => Some(@lib.I32(0))
      @lib.Instruction::I32LeU | @lib.Instruction::I64LeU => Some(@lib.I32(1))
      _ => None
    }
  } else {
    None
  }
}

///|
fn optimize_instructions_signed_domain_edge_compare_result(
  instr : @lib.Instruction,
  rhs_is_signed_min : Bool,
  rhs_is_signed_max : Bool,
) -> @lib.I32? {
  if rhs_is_signed_min {
    match instr {
      @lib.Instruction::I32LtS | @lib.Instruction::I64LtS => Some(@lib.I32(0))
      @lib.Instruction::I32GeS | @lib.Instruction::I64GeS => Some(@lib.I32(1))
      _ => None
    }
  } else if rhs_is_signed_max {
    match instr {
      @lib.Instruction::I32GtS | @lib.Instruction::I64GtS => Some(@lib.I32(0))
      @lib.Instruction::I32LeS | @lib.Instruction::I64LeS => Some(@lib.I32(1))
      _ => None
    }
  } else {
    None
  }
}

///|
fn optimize_instructions_try_fold_signed_domain_edge_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) {
    return false
  }
  let (rhs_is_signed_min, rhs_is_signed_max) = match instr {
    @lib.Instruction::I32LtS
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32GeS =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) => (raw == -2147483648, raw == 2147483647)
        _ => return false
      }
    @lib.Instruction::I64LtS
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64GeS =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) =>
          (raw == -9223372036854775808L, raw == 9223372036854775807L)
        _ => return false
      }
    _ => return false
  }
  match
    optimize_instructions_signed_domain_edge_compare_result(
      instr, rhs_is_signed_min, rhs_is_signed_max,
    ) {
    Some(result) => {
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_fold_unsigned_domain_edge_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let (rhs_is_zero, rhs_is_unsigned_max) = match instr {
    @lib.Instruction::I32LtU
    | @lib.Instruction::I32LeU
    | @lib.Instruction::I32GtU
    | @lib.Instruction::I32GeU =>
      match optimize_instructions_i32_const(func, dead, rhs_id) {
        Some(@lib.I32(raw)) => (raw == 0, raw == -1)
        _ => return false
      }
    @lib.Instruction::I64LtU
    | @lib.Instruction::I64LeU
    | @lib.Instruction::I64GtU
    | @lib.Instruction::I64GeU =>
      match optimize_instructions_i64_const(func, dead, rhs_id) {
        Some(@lib.I64(raw)) => (raw == 0L, raw == -1L)
        _ => return false
      }
    _ => return false
  }
  match
    optimize_instructions_unsigned_domain_edge_compare_result(
      instr, rhs_is_zero, rhs_is_unsigned_max,
    ) {
    Some(result) => {
      if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, lhs_id, result,
        )
      }
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_fold_same_local_integer_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      OiLocalGetLeafFact::from_node(func, dead, lhs_id).local_id,
      OiLocalGetLeafFact::from_node(func, dead, rhs_id).local_id,
      optimize_instructions_same_local_integer_compare_result(instr),
    ) {
    (Some(lhs_local), Some(rhs_local), Some(result)) if lhs_local == rhs_local => {
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_try_fold_same_local_integer_binary(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      OiLocalGetLeafFact::from_node(func, dead, lhs_id).local_id,
      OiLocalGetLeafFact::from_node(func, dead, rhs_id).local_id,
    ) {
    (Some(lhs_local), Some(rhs_local)) if lhs_local == rhs_local => ()
    _ => return false
  }
  match instr {
    @lib.Instruction::I32Sub | @lib.Instruction::I32Xor => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(0),
      )
      true
    }
    @lib.Instruction::I64Sub | @lib.Instruction::I64Xor => {
      optimize_instructions_replace_with_const_i64(
        ctx,
        func,
        node_id,
        @lib.I64(0L),
      )
      true
    }
    @lib.Instruction::I32And
    | @lib.Instruction::I32Or
    | @lib.Instruction::I64And
    | @lib.Instruction::I64Or => {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, lhs_id)
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_i32_sign_extension_range(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> (Int, Int, Int)? {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unary if node.child_count == 1 => ()
    _ => return None
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Extend8S) => Some((-128, 127, child_id))
    Some(@lib.Instruction::I32Extend16S) => Some((-32768, 32767, child_id))
    _ => None
  }
}

///|
fn optimize_instructions_i64_sign_extension_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unary if node.child_count == 1 => ()
    _ => return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I64Extend8S)
    | Some(@lib.Instruction::I64Extend16S)
    | Some(@lib.Instruction::I64Extend32S) => true
    _ => false
  }
}

///|
fn optimize_instructions_i32_sign_extension_equality_result(
  instr : @lib.Instruction,
  min_value : Int,
  max_value : Int,
  rhs : Int,
) -> @lib.I32? {
  if rhs >= min_value && rhs <= max_value {
    return None
  }
  match instr {
    @lib.Instruction::I32Eq => Some(@lib.I32(0))
    @lib.Instruction::I32Ne => Some(@lib.I32(1))
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_i32_sign_extension_equality_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let (min_value, max_value, drop_id) = match
    optimize_instructions_i32_sign_extension_range(func, dead, lhs_id) {
    Some(range) => range
    None => return false
  }
  let rhs = match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => raw
    _ => return false
  }
  match
    optimize_instructions_i32_sign_extension_equality_result(
      instr, min_value, max_value, rhs,
    ) {
    Some(result) => {
      if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, drop_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, drop_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, drop_id, result,
        )
      }
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_try_rewrite_i32_sign_extension_unsigned_top_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let mask = match
    optimize_instructions_i32_sign_extension_range(func, dead, lhs_id) {
    Some((-128, 127, child_id)) => (255, child_id)
    Some((-32768, 32767, child_id)) => (65535, child_id)
    _ => return false
  }
  match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) if raw == -1 => ()
    _ => return false
  }
  let replacement_instr = match instr {
    @lib.Instruction::I32LtU => @lib.Instruction::i32_ne()
    @lib.Instruction::I32GeU => @lib.Instruction::i32_eq()
    _ => return false
  }
  let (mask_value, child_id) = mask
  let masked = optimize_instructions_build_i32_binary(
    func,
    @lib.Instruction::i32_and(),
    child_id,
    @ir.hot_build_const_i32(func, @lib.I32(mask_value)),
  )
  optimize_instructions_replace_with_exact_compare(
    ctx,
    func,
    node_id,
    replacement_instr,
    masked,
    @ir.hot_build_const_i32(func, @lib.I32(mask_value)),
  )
  true
}

///|
fn optimize_instructions_try_rewrite_i64_sign_extension_unsigned_top_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_i64_sign_extension_node(func, dead, lhs_id) {
    return false
  }
  match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) if raw == -1L => ()
    _ => return false
  }
  let replacement_instr = match instr {
    @lib.Instruction::I64LtU => @lib.Instruction::i64_ne()
    @lib.Instruction::I64GeU => @lib.Instruction::i64_eq()
    _ => return false
  }
  optimize_instructions_replace_with_exact_compare(
    ctx,
    func,
    node_id,
    replacement_instr,
    lhs_id,
    @ir.hot_build_const_i64(func, @lib.I64(-1L)),
  )
  true
}

///|
fn optimize_instructions_i32_unsigned_max(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int? {
  optimize_instructions_i32_unsigned_max_fact_for_node(
    func, dead, scratch, node_id,
  )
}

///|
fn optimize_instructions_i32_masked_unsigned_compare_result(
  instr : @lib.Instruction,
  max_value : Int,
  rhs : Int,
) -> @lib.I32? {
  let rhs_outside = rhs < 0 || rhs > max_value
  if !rhs_outside {
    return None
  }
  match instr {
    @lib.Instruction::I32Eq
    | @lib.Instruction::I32GeU
    | @lib.Instruction::I32GtU => Some(@lib.I32(0))
    @lib.Instruction::I32Ne
    | @lib.Instruction::I32LtU
    | @lib.Instruction::I32LeU => Some(@lib.I32(1))
    @lib.Instruction::I32LtS =>
      if rhs <= 0 {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I32LeS =>
      if rhs < 0 {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I32GtS =>
      if rhs < 0 {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    @lib.Instruction::I32GeS =>
      if rhs <= 0 {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    _ => None
  }
}

///|
fn optimize_instructions_i32_signed_to_unsigned_compare_instr(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_ge_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_i32_masked_unsigned_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let max_value = match
    optimize_instructions_i32_unsigned_max(func, dead, scratch, lhs_id) {
    Some(value) => value
    None => return false
  }
  let rhs = match optimize_instructions_i32_const(func, dead, rhs_id) {
    Some(@lib.I32(raw)) => raw
    _ => return false
  }
  match
    optimize_instructions_i32_masked_unsigned_compare_result(
      instr, max_value, rhs,
    ) {
    Some(result) => {
      if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, lhs_id, result,
        )
      }
      true
    }
    None =>
      match optimize_instructions_i32_signed_to_unsigned_compare_instr(instr) {
        Some(replacement) if rhs >= 0 => {
          optimize_instructions_replace_with_exact_compare(
            ctx, func, node_id, replacement, lhs_id, rhs_id,
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_i64_unsigned_max(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int64? {
  optimize_instructions_i64_unsigned_max_fact_for_node(
    func, dead, scratch, node_id,
  )
}

///|
fn optimize_instructions_i64_masked_unsigned_compare_result(
  instr : @lib.Instruction,
  max_value : Int64,
  rhs : Int64,
) -> @lib.I32? {
  let rhs_outside = rhs < 0L || rhs > max_value
  if !rhs_outside {
    return None
  }
  match instr {
    @lib.Instruction::I64Eq
    | @lib.Instruction::I64GeU
    | @lib.Instruction::I64GtU => Some(@lib.I32(0))
    @lib.Instruction::I64Ne
    | @lib.Instruction::I64LtU
    | @lib.Instruction::I64LeU => Some(@lib.I32(1))
    @lib.Instruction::I64LtS =>
      if rhs <= 0L {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I64LeS =>
      if rhs < 0L {
        Some(@lib.I32(0))
      } else {
        Some(@lib.I32(1))
      }
    @lib.Instruction::I64GtS =>
      if rhs < 0L {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    @lib.Instruction::I64GeS =>
      if rhs <= 0L {
        Some(@lib.I32(1))
      } else {
        Some(@lib.I32(0))
      }
    _ => None
  }
}

///|
fn optimize_instructions_i64_signed_to_unsigned_compare_instr(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_lt_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_le_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_ge_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_fold_i64_masked_unsigned_compare(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let max_value = match
    optimize_instructions_i64_unsigned_max(func, dead, scratch, lhs_id) {
    Some(value) => value
    None => return false
  }
  let rhs = match optimize_instructions_i64_const(func, dead, rhs_id) {
    Some(@lib.I64(raw)) => raw
    _ => return false
  }
  match
    optimize_instructions_i64_masked_unsigned_compare_result(
      instr, max_value, rhs,
    ) {
    Some(result) => {
      if OiSideEffectFreeExpressionFact::proves_node_free(func, dead, lhs_id) ||
        optimize_instructions_node_effects_are_pure(ctx, func, lhs_id) {
        optimize_instructions_replace_with_const_i32(ctx, func, node_id, result)
      } else {
        optimize_instructions_replace_with_drop_then_const_i32(
          ctx, func, node_id, lhs_id, result,
        )
      }
      true
    }
    None =>
      match optimize_instructions_i64_signed_to_unsigned_compare_instr(instr) {
        Some(replacement) if rhs >= 0L => {
          optimize_instructions_replace_with_exact_compare(
            ctx, func, node_id, replacement, lhs_id, rhs_id,
          )
          true
        }
        _ => false
      }
  }
}

///|
fn optimize_instructions_try_rewrite_compare_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if optimize_instructions_should_keep_i64_eq_zero_if_condition(
      func, dead, scratch, node_id, instr, lhs_id, rhs_id,
    ) {
    return false
  }
  match instr {
    @lib.Instruction::I32Eq | @lib.Instruction::I32Ne => {
      let (eqz_id, const_value) = match
        (
          @ir.hot_node_exact_instr(func, lhs_id),
          @ir.hot_node_exact_instr(func, rhs_id),
          optimize_instructions_i32_const(func, dead, lhs_id),
          optimize_instructions_i32_const(func, dead, rhs_id),
        ) {
        (Some(@lib.Instruction::I32Eqz), _, _, Some(@lib.I32(raw)))
        | (Some(@lib.Instruction::I64Eqz), _, _, Some(@lib.I32(raw))) =>
          (lhs_id, raw)
        (_, Some(@lib.Instruction::I32Eqz), Some(@lib.I32(raw)), _)
        | (_, Some(@lib.Instruction::I64Eqz), Some(@lib.I32(raw)), _) =>
          (rhs_id, raw)
        _ => (-1, 0)
      }
      if eqz_id >= 0 &&
        (const_value == 0 || const_value == 1) &&
        @ir.hot_child_count(func, eqz_id) == 1 {
        let operand_id = @ir.hot_child_get(func, eqz_id, 0)
        if !OiLiveNodeFact::proves_node_live(func, dead, operand_id) {
          return false
        }
        let keep_eqz = match (instr, const_value) {
          (@lib.Instruction::I32Eq, 1) | (@lib.Instruction::I32Ne, 0) => true
          _ => false
        }
        let eqz_instr = @ir.hot_node_exact_instr(func, eqz_id)
        if keep_eqz {
          match eqz_instr {
            Some(@lib.Instruction::I64Eqz) =>
              optimize_instructions_replace_with_exact_unary(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_eqz(),
                operand_id,
              )
            _ =>
              optimize_instructions_replace_with_exact_unary(
                ctx,
                func,
                node_id,
                @lib.Instruction::i32_eqz(),
                operand_id,
              )
          }
        } else {
          match eqz_instr {
            Some(@lib.Instruction::I64Eqz) =>
              optimize_instructions_replace_with_exact_compare(
                ctx,
                func,
                node_id,
                @lib.Instruction::i64_ne(),
                operand_id,
                @ir.hot_build_const_i64(func, @lib.I64(0L)),
              )
            _ =>
              optimize_instructions_replace_with_exact_compare(
                ctx,
                func,
                node_id,
                @lib.Instruction::i32_ne(),
                operand_id,
                @ir.hot_build_const_i32(func, @lib.I32(0)),
              )
          }
        }
        return true
      }
    }
    _ => ()
  }
  match
    (
      instr,
      optimize_instructions_i32_const(func, dead, lhs_id),
      optimize_instructions_i32_const(func, dead, rhs_id),
    ) {
    (@lib.Instruction::I32Eq, Some(@lib.I32(0)), _) =>
      if OiRemainderInstructionFact::proves_node_remainder(func, dead, rhs_id) {
        ()
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i32_eqz(),
          rhs_id,
        )
        return true
      }
    (@lib.Instruction::I32Eq, _, Some(@lib.I32(0))) =>
      if OiRemainderInstructionFact::proves_node_remainder(func, dead, lhs_id) {
        ()
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i32_eqz(),
          lhs_id,
        )
        return true
      }
    _ => ()
  }
  match
    (
      instr,
      optimize_instructions_i64_const(func, dead, lhs_id),
      optimize_instructions_i64_const(func, dead, rhs_id),
    ) {
    (@lib.Instruction::I64Eq, Some(@lib.I64(0L)), _) =>
      if OiRemainderInstructionFact::proves_node_remainder(func, dead, rhs_id) {
        false
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i64_eqz(),
          rhs_id,
        )
        true
      }
    (@lib.Instruction::I64Eq, _, Some(@lib.I64(0L))) =>
      if OiRemainderInstructionFact::proves_node_remainder(func, dead, lhs_id) {
        false
      } else {
        optimize_instructions_replace_with_exact_unary(
          ctx,
          func,
          node_id,
          @lib.Instruction::i64_eqz(),
          lhs_id,
        )
        true
      }
    _ => false
  }
}

///|
fn optimize_instructions_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region : @ir.HotRegionRef,
  seen : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region, idx)
    if root_id < 0 {
      continue
    }
    if OiLiveNodeFact::proves_node_live(func, dead, root_id) {
      changed = optimize_instructions_visit_node(
          ctx, func, dead, root_id, seen, scratch,
        ) ||
        changed
    } else {
      // OI-G dead-shell parity: Binaryen still applies tiny bulk-memory lowering
      // inside syntactically unreachable if bodies. Keep this intentionally
      // narrow to the memory.copy/fill lowering helpers so dead-region traversal
      // does not broadly enable unrelated rewrites without red-first coverage.
      changed = match @ir.hot_node_get(func, root_id).op {
        @ir.HotOp::MemoryCopy =>
          optimize_instructions_try_expand_tiny_memory_copy(
            ctx, func, dead, root_id,
          ) ||
          changed
        @ir.HotOp::MemoryFill =>
          optimize_instructions_try_expand_tiny_memory_fill(
            ctx, func, dead, root_id,
          ) ||
          changed
        _ => changed
      }
    }
  }
  changed
}

///|
fn optimize_instructions_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  seen : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Bool {
  if !OiLiveNodeFact::proves_node_live(func, dead, node_id) {
    return false
  }
  if seen[node_id] {
    return false
  }
  seen[node_id] = true
  match ctx.perf {
    Some(perf) => perf_count_traversal_visit(perf)
    None => ()
  }
  let node = func.nodes[node_id]
  let mut changed = false
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = func.children[node.child_base + slot]
    if !OiLiveNodeFact::proves_node_live(func, dead, child_id) {
      continue
    }
    changed = optimize_instructions_visit_node(
        ctx, func, dead, child_id, seen, scratch,
      ) ||
      changed
  }
  changed = match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_visit_region(
        ctx,
        func,
        dead,
        @ir.hot_region_body_ref(func, node_id),
        seen,
        scratch,
      ) ||
      changed
    @ir.HotOp::If => {
      let then_changed = optimize_instructions_visit_region(
        ctx,
        func,
        dead,
        @ir.hot_region_then_ref(func, node_id),
        seen,
        scratch,
      )
      let else_changed = match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_visit_region(
            ctx, func, dead, else_region, seen, scratch,
          )
        None => false
      }
      then_changed || else_changed || changed
    }
    _ => changed
  }
  let local_changed = match node.op {
    @ir.HotOp::Unary =>
      if node.child_count != 1 {
        false
      } else {
        optimize_instructions_try_remove_redundant_sign_ext(
          ctx,
          func,
          dead,
          scratch,
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
        ) ||
        optimize_instructions_try_fold_eqz(
          ctx,
          func,
          dead,
          scratch,
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
        ) ||
        optimize_instructions_try_replace_zero_bits_with_zero(
          ctx, func, dead, scratch, node_id,
        )
      }
    @ir.HotOp::Binary =>
      if node.child_count != 2 {
        false
      } else {
        let initial_instr = func.instr_payloads[node.imm0].instr
        let initial_lhs = func.children[node.child_base]
        let initial_rhs = func.children[node.child_base + 1]
        let changed = optimize_instructions_try_fold_same_local_integer_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_apply_demorgan_and_eqz(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_fold_identity_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_fold_absorbing_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_remove_redundant_unsigned_mask(
            ctx, func, dead, scratch, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_canonicalize_signed_const_unsigned(
            ctx, func, dead, scratch, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_fold_exact_const_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_add_sub(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_negation(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_float_binary(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_shift(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_div_rem_power_of_two(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_sign_ext_idiom(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_combine_nested_const_shift(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_rewrite_shift(
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
          ) ||
          optimize_instructions_try_replace_zero_bits_with_zero(
            ctx, func, dead, scratch, node_id,
          )
        let current = func.nodes[node_id]
        let canonicalized = match current.op {
          @ir.HotOp::Binary => {
            let current_instr = func.instr_payloads[current.imm0].instr
            if !OiCommutativeInstructionFact::proves_instr_commutative(
                current_instr,
              ) {
              false
            } else {
              let current_lhs = func.children[current.child_base]
              let current_rhs = func.children[current.child_base + 1]
              optimize_instructions_try_canonicalize_commutative(
                ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
                scratch,
              )
            }
          }
          _ => false
        }
        if canonicalized {
          let current = func.nodes[node_id]
          let current_lhs = func.children[current.child_base]
          let current_rhs = func.children[current.child_base + 1]
          let current_instr = func.instr_payloads[current.imm0].instr
          optimize_instructions_try_fold_same_local_integer_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_apply_demorgan_and_eqz(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_identity_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_absorbing_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_remove_redundant_unsigned_mask(
            ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_exact_const_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_add_sub(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_negation(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_float_binary(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_mul_shift(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_div_rem_power_of_two(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_sign_ext_idiom(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_combine_nested_const_shift(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_shift(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_replace_zero_bits_with_zero(
            ctx, func, dead, scratch, node_id,
          ) ||
          true
        } else {
          changed
        }
      }
    @ir.HotOp::Convert =>
      if node.child_count != 1 {
        false
      } else {
        optimize_instructions_try_rewrite_reinterpret_load_result(
          ctx, func, dead, node_id,
        ) ||
        optimize_instructions_try_rewrite_i64_extend_i32_load_result(
          ctx, func, dead, node_id,
        ) ||
        optimize_instructions_try_fold_convert(
          ctx,
          func,
          dead,
          scratch,
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
        ) ||
        optimize_instructions_try_replace_zero_bits_with_zero(
          ctx, func, dead, scratch, node_id,
        )
      }
    @ir.HotOp::Compare =>
      if node.child_count != 2 {
        false
      } else {
        let mut current_instr = func.instr_payloads[node.imm0].instr
        let mut current_lhs = func.children[node.child_base]
        let mut current_rhs = func.children[node.child_base + 1]
        let mut changed = false
        if optimize_instructions_try_fold_integer_const_eq_ne_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_signed_domain_edge_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_unsigned_domain_edge_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_fold_same_local_integer_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          ) ||
          optimize_instructions_try_rewrite_compare_eqz(
            ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
          ) {
          true
        } else {
          if optimize_instructions_try_canonicalize_signed_const_unsigned(
              ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
            ) {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }
          if optimize_instructions_try_canonicalize_relational_const(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            ) {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }

          let relational_operands_changed = optimize_instructions_try_canonicalize_relational_operands(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs, scratch,
          )
          if relational_operands_changed {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }
          if optimize_instructions_try_canonicalize_compare_const(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            ) {
            changed = true
            let current = func.nodes[node_id]
            current_instr = func.instr_payloads[current.imm0].instr
            current_lhs = func.children[current.child_base]
            current_rhs = func.children[current.child_base + 1]
          }
          let range_folded = optimize_instructions_try_fold_i32_sign_extension_equality_compare(
            ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
          )
          let signext_top_rewritten = if range_folded {
            false
          } else {
            optimize_instructions_try_rewrite_i32_sign_extension_unsigned_top_compare(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            ) ||
            optimize_instructions_try_rewrite_i64_sign_extension_unsigned_top_compare(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            )
          }
          let masked_unsigned_folded = if range_folded || signext_top_rewritten {
            false
          } else {
            optimize_instructions_try_fold_i32_masked_unsigned_compare(
              ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
            ) ||
            optimize_instructions_try_fold_i64_masked_unsigned_compare(
              ctx, func, dead, scratch, node_id, current_instr, current_lhs, current_rhs,
            )
          }
          changed = range_folded ||
            signext_top_rewritten ||
            masked_unsigned_folded ||
            changed
          let zero_folded = if masked_unsigned_folded ||
            signext_top_rewritten ||
            range_folded {
            false
          } else {
            optimize_instructions_try_fold_compare_zero(
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
            )
          }
          changed = zero_folded || changed
          if zero_folded || masked_unsigned_folded || range_folded {
            changed
          } else {
            let canonicalized = if OiCommutativeInstructionFact::proves_instr_commutative(
                current_instr,
              ) {
              optimize_instructions_try_canonicalize_commutative(
                ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
                scratch,
              )
            } else {
              false
            }
            if canonicalized {
              let current = func.nodes[node_id]
              let next_instr = func.instr_payloads[current.imm0].instr
              let next_lhs = func.children[current.child_base]
              let next_rhs = func.children[current.child_base + 1]
              optimize_instructions_try_canonicalize_compare_const(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_integer_const_eq_ne_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_signed_domain_edge_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_unsigned_domain_edge_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_i32_sign_extension_equality_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_rewrite_i32_sign_extension_unsigned_top_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_rewrite_i64_sign_extension_unsigned_top_compare(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_i32_masked_unsigned_compare(
                ctx, func, dead, scratch, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_i64_masked_unsigned_compare(
                ctx, func, dead, scratch, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              optimize_instructions_try_fold_compare_zero(
                ctx, func, dead, node_id, next_instr, next_lhs, next_rhs,
              ) ||
              true
            } else {
              changed
            }
          }
        }
      }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      optimize_instructions_try_remove_ref_as_non_null_local_write_trap_check(
        ctx, func, node_id,
      )
    @ir.HotOp::Select =>
      optimize_instructions_try_fold_const_select(ctx, func, dead, node_id)
    @ir.HotOp::Drop =>
      optimize_instructions_try_collapse_dropped_unreachable_block(
        ctx, func, node_id,
      )
    @ir.HotOp::TupleExtract =>
      optimize_instructions_try_fold_tuple_extract_tuple_make(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::RefIsNull =>
      match OiRefIsNullRewritePlanFact::from_node(ctx, func, node_id) {
        Some(plan_fact) => plan_fact.apply(ctx, func, node_id)
        None => false
      }
    @ir.HotOp::RefTest | @ir.HotOp::RefTestDesc =>
      optimize_instructions_try_fold_ref_test_null(ctx, func, node_id)
    @ir.HotOp::RefCast =>
      optimize_instructions_try_fold_ref_cast_null(ctx, func, node_id) ||
      optimize_instructions_try_replace_ref_cast_unreachable_operand(
        ctx, func, node_id,
      )
    @ir.HotOp::RefCastDescEq =>
      optimize_instructions_try_replace_ref_cast_desc_eq_trapping_descriptor_operand(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_skip_ref_cast_desc_eq_exact_success_traps_never_happen(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_skip_ref_cast_desc_eq_traps_never_happen(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_ref_cast_desc_eq_null(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_ref_cast_desc_eq_exact_descriptor_miss(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_simplify_ref_cast_desc_eq_descriptor_operand(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_narrow_ref_cast_desc_eq_result_type(
        ctx, func, node_id,
      )
    @ir.HotOp::Heap =>
      optimize_instructions_try_replace_ref_get_desc_unreachable_operand(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_trap_standalone_ref_get_desc_known_null_child(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_move_standalone_ref_get_desc_null_check(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_fold_ref_as_non_null(ctx, func, node_id) ||
      optimize_instructions_try_rewrite_ref_eq_null(ctx, func, dead, node_id) ||
      optimize_instructions_try_rewrite_array_new_default_init(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_rewrite_array_new_single_fixed(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_rewrite_array_new_fixed_repeated_values(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_fold_array_len_new_fixed(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_array_get_new_fixed(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_remove_array_set_fresh_array(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_struct_get_struct_new(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef =>
      optimize_instructions_try_directize_ref_func_call_ref(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail =>
      optimize_instructions_try_replace_unreachable_guard_cast_branch(
        ctx, func, node_id,
      )
    @ir.HotOp::Load =>
      optimize_instructions_try_fold_const_memory_access_offset(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Atomic =>
      optimize_instructions_try_rewrite_aggregate_atomic(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_const_memory_access_offset(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Store =>
      optimize_instructions_try_fold_const_memory_access_offset(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_truncate_narrow_store_const_value(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_drop_narrow_store_value_mask(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_rewrite_reinterpret_store_value(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_widen_store_of_wrap_i64(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::MemoryCopy =>
      optimize_instructions_try_expand_tiny_memory_copy(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::MemoryFill =>
      optimize_instructions_try_expand_tiny_memory_fill(
        ctx, func, dead, node_id,
      )
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_try_narrow_null_cast_boundary_block(
        ctx, func, node_id,
      ) ||
      optimize_instructions_try_collapse_dead_region_suffix(
        ctx,
        func,
        dead,
        @ir.hot_region_body_ref(func, node_id),
        @ir.hot_control_node_label(func, node_id),
      )
    @ir.HotOp::If =>
      optimize_instructions_try_sink_same_global_set_if(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_fold_constant_if_condition(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_optimize_if_condition(ctx, func, dead, node_id) ||
      optimize_instructions_try_wrap_boolean_if_value_in_eqz(
        ctx, func, dead, node_id,
      ) ||
      optimize_instructions_try_collapse_dead_region_suffix(
        ctx,
        func,
        dead,
        @ir.hot_region_then_ref(func, node_id),
        @ir.hot_control_node_label(func, node_id),
      ) ||
      (match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_try_collapse_dead_region_suffix(
            ctx,
            func,
            dead,
            else_region,
            @ir.hot_control_node_label(func, node_id),
          )
        None => false
      })
    _ => false
  }
  local_changed || changed
}

///|
priv struct OiUnsupportedAggregateAtomicReceiverFact {
  found_unsupported_receiver : Bool
}

///|
fn OiUnsupportedAggregateAtomicReceiverFact::from_func(
  func : @ir.HotFunc,
) -> OiUnsupportedAggregateAtomicReceiverFact {
  // Current HOT can contain aggregate atomic receiver-less shapes that OI cannot
  // safely rewrite. Keep the fail-closed preflight as a named representation
  // fact until the aggregate-atomic receiver representation is repaired.
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_exact_instr(func, node_id) {
      Some(@lib.Instruction::StructAtomicRmw(_, _, _))
      | Some(@lib.Instruction::StructAtomicCmpxchg(_, _)) =>
        if @ir.hot_child_count(func, node_id) == 0 {
          return { found_unsupported_receiver: true }
        }
      _ => ()
    }
  }
  { found_unsupported_receiver: false }
}

///|
fn OiUnsupportedAggregateAtomicReceiverFact::requires_fail_closed_skip(
  self : OiUnsupportedAggregateAtomicReceiverFact,
) -> Bool {
  self.found_unsupported_receiver
}

///|
fn optimize_instructions_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if OiUnsupportedAggregateAtomicReceiverFact::from_func(func).requires_fail_closed_skip() {
    return HotPassResult::unchanged()
  }
  let mut changed = false
  let node_count = @ir.hot_node_count(func)
  let seen = @bitset.BitSet::new(node_count)
  let dead = @bitset.BitSet::new(node_count)
  let scratch = OptimizeInstructionsScratch::new(
    node_count,
    @ir.hot_local_count(func),
  )
  for free_id in func.free_nodes {
    if free_id >= 0 && free_id < dead.length() {
      dead[free_id] = true
    }
  }
  let sign_ext_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:collect-sign-ext-facts",
  )
  optimize_instructions_collect_sign_ext_facts(func, dead, scratch)
  perf_stop_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:collect-sign-ext-facts",
    sign_ext_start_us,
  )
  let unsigned_max_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:collect-unsigned-max-facts",
  )
  optimize_instructions_collect_unsigned_max_facts(func, dead, scratch)
  perf_stop_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:collect-unsigned-max-facts",
    unsigned_max_start_us,
  )
  let visit_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:visit-roots",
  )
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    changed = optimize_instructions_visit_node(
        ctx,
        func,
        dead,
        func.roots[slot],
        seen,
        scratch,
      ) ||
      changed
  }
  perf_stop_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:visit-roots",
    visit_start_us,
  )
  let dead_suffix_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:collapse-root-dead-suffix",
  )
  changed = optimize_instructions_try_collapse_dead_region_suffix(
      ctx,
      func,
      dead,
      @ir.HotRegionRef::root(),
      -1,
    ) ||
    changed
  perf_stop_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:collapse-root-dead-suffix",
    dead_suffix_start_us,
  )
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
