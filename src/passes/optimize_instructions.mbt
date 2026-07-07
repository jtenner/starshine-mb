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
  let ref_type = match
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => Some(ref_type)
    _ => None
  }
  let known_null = match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::RefNull => true
    _ => false
  }
  let known_non_null = if known_null {
    false
  } else {
    match ref_type {
      Some(ref_type) if ref_type.is_non_nullable() => true
      _ => optimize_instructions_ref_is_known_non_null(func, node_id)
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
fn optimize_instructions_node_is_br_on_fallthrough_tail(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => @ir.hot_child_count(func, node_id) > 0
    _ => false
  }
}

///|
fn optimize_instructions_region_has_branch_control_before_tail(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count <= 1 {
    return false
  }
  for slot = 0; slot < root_count - 1; slot = slot + 1 {
    if optimize_instructions_descriptor_expr_has_branch_control(
        func,
        @ir.hot_region_get(func, region_ref, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_region_ref_fallthrough_type(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> @lib.RefType? {
  match optimize_instructions_region_tail_id(func, region_ref) {
    Some(tail_id) => {
      if optimize_instructions_descriptor_region_has_branch_control(
          func, region_ref,
        ) {
        if !optimize_instructions_node_is_br_on_fallthrough_tail(func, tail_id) ||
          optimize_instructions_region_has_branch_control_before_tail(
            func, region_ref,
          ) {
          return None
        }
      }
      OiRefFallthroughFact::from_node(ctx, func, tail_id).ref_type
    }
    None => None
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
        optimize_instructions_region_ref_fallthrough_type(ctx, func, body_ref) {
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
              optimize_instructions_region_ref_fallthrough_type(
                ctx, func, else_ref,
              ) {
              Some(ref_type) => return { ref_type: Some(ref_type) }
              None => ()
            }
          } else if else_stops && !then_stops {
            match
              optimize_instructions_region_ref_fallthrough_type(
                ctx, func, then_ref,
              ) {
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
      optimize_instructions_ref_type_heap_matches_target(ctx, ref_type, target)
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
      optimize_instructions_ref_type_heap_matches_target(ctx, ref_type, target)
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
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match self.ref_type {
    Some(ref_type) => {
      let source = ref_type.get_heap_type()
      match (source, target) {
        (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => ()
        _ => return false
      }
      source != target &&
      (ref_type.is_non_nullable() || !target_nullable) &&
      optimize_instructions_heap_matches_target(module_ctx, source, target, 512)
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
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match self.ref_type {
    Some(ref_type) => {
      if ref_type.is_non_nullable() {
        return false
      }
      let source = ref_type.get_heap_type()
      match (source, target) {
        (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => ()
        _ => return false
      }
      source != target &&
      (
        ref_type.is_exact() ||
        optimize_instructions_heap_matches_target(
          module_ctx, source, target, 512,
        )
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
      optimize_instructions_heap_is_final(module_ctx, target)
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
      if source == target {
        Some((ref_type.is_nullable(), ref_type.is_exact()))
      } else if optimize_instructions_heap_is_known_subtype(ctx, source, target) {
        // A strict subtype operand proves heap compatibility, but it does not
        // prove the value is an exact instance of the supertype target.
        Some((ref_type.is_nullable(), false))
      } else {
        None
      }
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
fn OiDescriptorOperandFact::from_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> OiDescriptorOperandFact {
  {
    type_fact: OiDescriptorTypeFact::from_node(ctx, func, node_id),
    traps_without_effects: optimize_instructions_descriptor_operand_traps_without_effects(
      func, node_id,
    ),
    can_erase: optimize_instructions_descriptor_operand_can_erase(
      ctx, func, dead, node_id,
    ),
    should_localize_when_skipped: optimize_instructions_descriptor_operand_should_localize_when_skipped(
      func, node_id,
    ),
    may_drop_exactness_for_tnh_escaping_ref_get_desc: optimize_instructions_descriptor_skip_may_drop_exactness_for_tnh_escaping_ref_get_desc(
      func, node_id,
    ),
  }
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
priv struct OiRefTestOperandFact {
  ref_fact : OiRefFact
  producer_fact : OiRefProducerFact
  source_type : @lib.RefType?
  is_ref_i31_literal : Bool
  is_ref_func_literal : Bool
}

///|
fn OiRefTestOperandFact::from_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  operand_id : Int,
) -> OiRefTestOperandFact {
  let ref_fact = OiRefFact::from_node(func, operand_id)
  let producer_fact = OiRefProducerFact::from_node(ctx, func, operand_id)
  let (is_ref_i31_literal, is_ref_func_literal) = if operand_id >= 0 &&
    @ir.hot_node_is_live(func, operand_id) {
    let node = @ir.hot_node_get(func, operand_id)
    let is_i31 = match @ir.hot_node_exact_instr(func, operand_id) {
      Some(@lib.Instruction::RefI31) => true
      _ => false
    }
    let is_ref_func = match node.op {
      @ir.HotOp::RefFunc => true
      _ => false
    }
    (is_i31, is_ref_func)
  } else {
    (false, false)
  }
  {
    ref_fact,
    producer_fact,
    source_type: ref_fact.ref_type,
    is_ref_i31_literal,
    is_ref_func_literal,
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
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  source == target ||
  (
    source == @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
    optimize_instructions_ref_i31_matches_target(target)
  ) ||
  optimize_instructions_abs_struct_array_matches_target(source, target)
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
      optimize_instructions_heap_is_final(module_ctx, target)
    None => false
  }
}

///|
fn OiRefTestOperandFact::nullable_matches_target(
  self : OiRefTestOperandFact,
  target : @lib.HeapType,
) -> Bool {
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_nullable() &&
      OiRefTestOperandFact::heap_matches_target_without_subtyping(
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
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match self.source_type {
    Some(ref_type) => {
      if ref_type.is_non_nullable() {
        return false
      }
      let source = ref_type.get_heap_type()
      match (source, target) {
        (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => ()
        _ => return false
      }
      source != target &&
      (
        ref_type.is_exact() ||
        optimize_instructions_heap_matches_target(
          module_ctx, source, target, 512,
        )
      )
    }
    None => false
  }
}

///|
fn OiRefTestOperandFact::non_null_matches_target(
  self : OiRefTestOperandFact,
  target : @lib.HeapType,
) -> Bool {
  if self.is_ref_func_literal {
    return optimize_instructions_ref_func_matches_target(target)
  }
  if self.is_ref_i31_literal {
    return optimize_instructions_ref_i31_matches_target(target)
  }
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_non_nullable() &&
      OiRefTestOperandFact::heap_matches_target_without_subtyping(
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
  if self.is_ref_i31_literal {
    return optimize_instructions_ref_i31_cannot_match_target(target)
  }
  match self.source_type {
    Some(ref_type) =>
      ref_type.is_non_nullable() &&
      (
        (
          ref_type.get_heap_type() ==
          @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
          optimize_instructions_ref_i31_cannot_match_target(target)
        ) ||
        optimize_instructions_abs_struct_array_disjoint(
          ref_type.get_heap_type(),
          target,
        ) ||
        optimize_instructions_concrete_source_has_no_target_overlap(
          ctx.module_ctx,
          ref_type.get_heap_type(),
          target,
        )
      )
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
      (
        ref_type.get_heap_type() == @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
        optimize_instructions_ref_i31_cannot_match_target(target)
      ) ||
      optimize_instructions_abs_struct_array_disjoint(
        ref_type.get_heap_type(),
        target,
      ) ||
      optimize_instructions_concrete_source_has_no_target_overlap(
        ctx.module_ctx,
        ref_type.get_heap_type(),
        target,
      )
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
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match self.source_type {
    Some(ref_type) => {
      let source = ref_type.get_heap_type()
      match (source, target) {
        (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => ()
        _ => return false
      }
      source != target &&
      (ref_type.is_non_nullable() || !target_nullable) &&
      optimize_instructions_heap_matches_target(module_ctx, source, target, 512)
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
    self.nullable_matches_target(target) ||
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
      self.non_null_matches_target(target) ||
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
      self.nullable_matches_target(target) ||
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
    let kind = match
      operand_fact.descriptor_matches_or_subtypes_heap(ctx, target) {
      Some((operand_nullable, _)) =>
        if !nullable && operand_nullable {
          RefTestSuccessOnlyIfNonNull
        } else {
          RefTestSuccess
        }
      None => RefTestUnknown
    }
    return { kind, }
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
  let result_fact = OiRefTestResultFact::from_test(ctx, func, test_fact)
  if result_fact.rewrite_to_ref_is_non_null {
    return Some({
      kind: RefTestRewriteToNonNullCheck,
      test_fact,
      const_result: None,
    })
  }
  if result_fact.rewrite_to_ref_is_null {
    return Some({
      kind: RefTestRewriteToNullCheck,
      test_fact,
      const_result: None,
    })
  }
  match result_fact.known_const_result {
    Some(value) => {
      let operand_id = test_fact.operand_id
      let can_erase_operand = (
          value == @lib.I32(0) &&
          (
            optimize_instructions_is_trivially_pure_operand(func, operand_id) ||
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
        test_fact,
        const_result: Some(value),
      })
    }
    None => None
  }
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
    RefTestRewriteToNonNullCheck => {
      optimize_instructions_replace_with_ref_is_non_null_test(
        ctx, func, node_id, operand_id,
      )
      true
    }
    RefTestRewriteToNullCheck => {
      optimize_instructions_replace_with_ref_is_null(
        ctx, func, node_id, operand_id,
      )
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
priv enum OiRefCastRewritePlanKind {
  RefCastForwardOperand
  RefCastUnreachable
  RefCastDropOperandThenUnreachable
  RefCastAsNonNull
  RefCastNullrefCast
}

///|
priv struct OiRefCastRewritePlanFact {
  kind : OiRefCastRewritePlanKind
  cast_fact : OiRefCastFact
}

///|
fn OiRefCastRewritePlanFact::from_cast(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  cast_fact : OiRefCastFact,
) -> OiRefCastRewritePlanFact? {
  // Binaryen v130 `visitRefCast` routes source-level cast outcomes through
  // `GCTypeUtils::evaluateCastCheck` and then chooses whether to forward the
  // operand, keep only a null check, materialize null, or trap. Keep the
  // represented Starshine subset as a plan fact so the visitor does not own a
  // scanner-like cascade of local/ref/null/exactness predicates.
  let operand_id = cast_fact.operand_id
  let nullable = cast_fact.nullable
  let exact = cast_fact.exact
  let target = cast_fact.target
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::RefNull =>
      return Some({
        kind: if nullable {
          RefCastForwardOperand
        } else {
          RefCastUnreachable
        },
        cast_fact,
      })
    _ => ()
  }
  if not(nullable) &&
    (
      not(exact) ||
      optimize_instructions_ref_operand_has_exact_heap(func, operand_id, target)
    ) &&
    optimize_instructions_ref_operand_is_nullable_exact_heap(
      func, operand_id, target,
    ) {
    return Some({ kind: RefCastAsNonNull, cast_fact })
  }
  if exact &&
    optimize_instructions_ref_operand_matches_nullable_exact_target_only_as_null(
      ctx, func, operand_id, target, nullable,
    ) {
    return Some({ kind: RefCastNullrefCast, cast_fact })
  }
  if (
      not(exact) ||
      optimize_instructions_ref_operand_has_exact_heap(func, operand_id, target)
    ) &&
    (
      optimize_instructions_ref_is_known_match_for_target(
        func, operand_id, target,
      ) ||
      (
        nullable &&
        optimize_instructions_ref_is_known_match_for_nullable_target(
          func, operand_id, target,
        )
      )
    ) {
    return Some({ kind: RefCastForwardOperand, cast_fact })
  }
  if optimize_instructions_ref_is_known_miss_for_target(
      ctx, func, operand_id, target,
    ) ||
    (
      exact &&
      (
        optimize_instructions_ref_operand_misses_exact_target(
          func, operand_id, target, nullable,
        ) ||
        optimize_instructions_ref_operand_misses_exact_target_by_strict_subtype(
          ctx, func, operand_id, target, nullable,
        )
      )
    ) ||
    (
      not(nullable) &&
      optimize_instructions_ref_is_null_or_known_miss_for_non_null_target(
        ctx, func, operand_id, target,
      )
    ) {
    let kind = if optimize_instructions_is_trivially_pure_operand(
        func, operand_id,
      ) ||
      optimize_instructions_node_effects_are_pure(ctx, func, operand_id) {
      RefCastUnreachable
    } else {
      RefCastDropOperandThenUnreachable
    }
    return Some({ kind, cast_fact })
  }
  None
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
  }
}

///|
priv struct OiDescriptorCastFact {
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
    nullable,
    exact,
    target,
    operand_id: @ir.hot_child_get(func, node_id, 0),
    descriptor_id: @ir.hot_child_get(func, node_id, 1),
  })
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
  Some({
    cast_fact,
    descriptor_exactly_describes_target: optimize_instructions_descriptor_operand_exactly_describes_target(
      ctx,
      func,
      cast_fact.descriptor_id,
      cast_fact.target,
    ),
    ref_operand_misses_target: optimize_instructions_ref_operand_misses_exact_target(
      func,
      cast_fact.operand_id,
      cast_fact.target,
      cast_fact.nullable,
    ) ||
    optimize_instructions_ref_operand_misses_exact_target_by_strict_subtype(
      ctx,
      func,
      cast_fact.operand_id,
      cast_fact.target,
      cast_fact.nullable,
    ),
    descriptor_can_erase: optimize_instructions_descriptor_operand_can_erase(
      ctx,
      func,
      dead,
      cast_fact.descriptor_id,
    ),
    ref_operand_can_erase: optimize_instructions_is_trivially_pure_operand(
      func,
      cast_fact.operand_id,
    ) ||
    optimize_instructions_node_effects_are_pure(ctx, func, cast_fact.operand_id),
    ref_operand_can_drop_before_unreachable: optimize_instructions_exact_descriptor_miss_operand_can_drop_before_unreachable(
      func,
      cast_fact.operand_id,
    ) ||
    optimize_instructions_exact_descriptor_miss_reference_call_can_drop_before_unreachable(
      func,
      cast_fact.operand_id,
    ),
    descriptor_can_drop_before_unreachable: optimize_instructions_exact_descriptor_miss_operand_can_drop_before_unreachable(
      func,
      cast_fact.descriptor_id,
    ),
    descriptor_call_can_drop_before_unreachable: optimize_instructions_exact_descriptor_miss_descriptor_call_can_drop_before_unreachable(
      func,
      cast_fact.descriptor_id,
    ),
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
      if optimize_instructions_heap_is_known_subtype(
          ctx,
          described_heap,
          cast_fact.target,
        ) &&
        !optimize_instructions_ref_operand_is_exact_heap(
          ctx,
          func,
          cast_fact.operand_id,
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
  } else if optimize_instructions_descriptor_skip_must_preserve_operand_order(
      func,
      cast_fact.operand_id,
    ) {
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
priv enum OiDescriptorOperandSimplificationKind {
  DescriptorOperandDirectizeOnly
  DescriptorOperandStripRefAsNonNull
  DescriptorOperandMoveRefGetDescNullCheck
}

///|
priv struct OiDescriptorOperandSimplificationFact {
  cast_fact : OiDescriptorCastFact
  directize_operand_candidate : Bool
  directize_descriptor_candidate : Bool
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
  let directize_operand_candidate = match
    @ir.hot_node_get(func, cast_fact.operand_id).op {
    @ir.HotOp::CallRef => true
    _ => false
  }
  let directize_descriptor_candidate = match
    @ir.hot_node_get(func, cast_fact.descriptor_id).op {
    @ir.HotOp::CallRef => true
    _ => false
  }
  let has_directize_candidate = directize_operand_candidate ||
    directize_descriptor_candidate
  let kind = match @ir.hot_node_exact_instr(func, cast_fact.descriptor_id) {
    Some(@lib.Instruction::RefAsNonNull) =>
      if @ir.hot_child_count(func, cast_fact.descriptor_id) == 1 {
        DescriptorOperandStripRefAsNonNull
      } else if has_directize_candidate {
        DescriptorOperandDirectizeOnly
      } else {
        return None
      }
    Some(@lib.Instruction::RefGetDesc(_)) =>
      DescriptorOperandMoveRefGetDescNullCheck
    _ =>
      if has_directize_candidate {
        DescriptorOperandDirectizeOnly
      } else {
        return None
      }
  }
  Some({
    cast_fact,
    directize_operand_candidate,
    directize_descriptor_candidate,
    kind,
  })
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
  let directized_operand = if fact.directize_operand_candidate {
    optimize_instructions_try_directize_ref_func_call_ref(
      ctx,
      func,
      dead,
      cast_fact.operand_id,
    )
  } else {
    false
  }
  let directized_descriptor = if fact.directize_descriptor_candidate {
    optimize_instructions_try_directize_ref_func_call_ref(
      ctx,
      func,
      dead,
      cast_fact.descriptor_id,
    )
  } else {
    false
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
    DescriptorOperandDirectizeOnly =>
      directized_operand || directized_descriptor
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
      directized_operand ||
      directized_descriptor
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
      if optimize_instructions_standalone_ref_get_desc_ref_null_leaf_is_known_null(
          func, nullable_child,
        ) {
        Some({
          kind: RefGetDescKnownNullDirectTrap,
          get_desc_fact,
          preserve_child_id: -1,
        })
      } else {
        None
      }
    @ir.HotOp::LocalTee =>
      if optimize_instructions_standalone_ref_get_desc_local_tee_child_is_known_null(
          func, nullable_child,
        ) {
        Some({
          kind: RefGetDescKnownNullPreserveChild,
          get_desc_fact,
          preserve_child_id: nullable_child,
        })
      } else {
        None
      }
    @ir.HotOp::Block =>
      if optimize_instructions_standalone_ref_get_desc_branch_free_block_child_is_known_null(
          func, nullable_child,
        ) {
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
      if optimize_instructions_standalone_ref_get_desc_nullable_ref_leaf_can_move_null_check(
          func, child_id,
        ) {
        RefGetDescNullableLeafMove
      } else {
        return None
      }
    @ir.HotOp::LocalTee =>
      if optimize_instructions_standalone_ref_get_desc_local_tee_child_can_move_null_check(
          func, child_id,
        ) {
        RefGetDescNullableLocalTeeMove
      } else {
        return None
      }
    @ir.HotOp::Call | @ir.HotOp::CallIndirect =>
      if optimize_instructions_standalone_ref_get_desc_call_child_can_move_null_check(
          func, child_id,
        ) {
        RefGetDescNullableCallMove
      } else {
        return None
      }
    @ir.HotOp::Select =>
      if optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
          func, child_id,
        ) &&
        !optimize_instructions_descriptor_expr_has_escaping_branch_control(
          func, child_id,
        ) {
        RefGetDescNullableSelectMove
      } else {
        return None
      }
    @ir.HotOp::If =>
      if optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
          func, child_id,
        ) &&
        optimize_instructions_descriptor_nullable_if_child_can_move_null_check_with_effects(
          func, child_id,
        ) {
        RefGetDescNullableIfMove
      } else {
        return None
      }
    @ir.HotOp::Block =>
      if optimize_instructions_standalone_ref_get_desc_block_child_can_move_null_check(
          func, child_id,
        ) {
        RefGetDescNullableBlockMove
      } else {
        return None
      }
    _ => return None
  }
  let descriptor_operand_can_move = match child.op {
    @ir.HotOp::LocalGet => true
    @ir.HotOp::Block | @ir.HotOp::Select =>
      !optimize_instructions_descriptor_expr_has_escaping_branch_control(
        func, child_id,
      )
    @ir.HotOp::If =>
      optimize_instructions_descriptor_nullable_if_child_can_move_null_check_with_effects(
        func, child_id,
      )
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
fn OiRefGetDescFact::operand_can_erase(
  self : OiRefGetDescFact,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> Bool {
  let operand_fact = OiRefFact::from_node(func, self.child_id)
  (operand_fact.type_is_non_nullable() || operand_fact.is_known_non_null()) &&
  optimize_instructions_is_side_effect_free_expr(func, dead, self.child_id)
}

///|
fn OiRefGetDescFact::operand_can_erase_traps_never_happen(
  self : OiRefGetDescFact,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
) -> Bool {
  match self.explicit_nullable_child() {
    Some(nullable_child) =>
      optimize_instructions_descriptor_nullable_child_can_erase_traps_never_happen(
        func, dead, nullable_child,
      )
    None => false
  }
}

///|
fn OiRefGetDescFact::traps_without_effects(
  self : OiRefGetDescFact,
  func : @ir.HotFunc,
) -> Bool {
  if self.child_is_unreachable(func) {
    return true
  }
  match self.explicit_nullable_child() {
    Some(nullable_child) =>
      match @ir.hot_node_get(func, nullable_child).op {
        @ir.HotOp::RefNull => true
        _ => false
      }
    None => false
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
    if !optimize_instructions_node_is_live(func, dead, node_id) {
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
    if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
fn optimize_instructions_scan_sign_ext_local_sets_region(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  region : @ir.HotRegionRef,
) -> Unit {
  for i = 0; i < @ir.hot_region_root_count(func, region); i = i + 1 {
    optimize_instructions_scan_sign_ext_local_sets_expr(
      func,
      dead,
      scratch,
      @ir.hot_region_get(func, region, i),
    )
  }
}

///|
fn optimize_instructions_scan_sign_ext_local_sets_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Unit {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_scan_sign_ext_local_sets_expr(
      func,
      dead,
      scratch,
      func.children[node.child_base + slot],
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_scan_sign_ext_local_sets_region(
        func,
        dead,
        scratch,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      optimize_instructions_scan_sign_ext_local_sets_region(
        func,
        dead,
        scratch,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_scan_sign_ext_local_sets_region(
            func, dead, scratch, else_region,
          )
        None => ()
      }
    }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.child_count == 1 &&
      node.imm0 >= @ir.hot_local_param_count(func) =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(val_type) if val_type == @lib.ValType::i32() ||
          val_type == @lib.ValType::i64() =>
          scratch.local_facts.merge_sign_ext_bits_for_local(
            node.imm0,
            OiSignExtValueFact::from_assigned_value(
              func,
              dead,
              func.children[node.child_base],
            ).bits,
          )
        _ => ()
      }
    _ => ()
  }
}

///|
fn optimize_instructions_scan_sign_ext_facts(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
) -> Unit {
  if scratch.local_facts.sign_ext_ready {
    return
  }
  for slot = 0; slot < func.roots.length(); slot = slot + 1 {
    optimize_instructions_scan_sign_ext_local_sets_expr(
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
fn OiUnsignedMaxValueFact::i32_max_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  local_facts : OptimizeInstructionsLocalFacts?,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Load8U(_)) => return Some(255)
    Some(@lib.Instruction::I32Load16U(_)) => return Some(65535)
    _ => ()
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
          let (mask, value_id) = match
            optimize_instructions_i32_const(func, dead, rhs_id) {
            Some(@lib.I32(raw)) => (raw, lhs_id)
            _ =>
              match optimize_instructions_i32_const(func, dead, lhs_id) {
                Some(@lib.I32(raw)) => (raw, rhs_id)
                _ => return None
              }
          }
          if mask < 0 {
            None
          } else {
            match
              OiUnsignedMaxValueFact::i32_max_for_node(
                func, dead, local_facts, value_id,
              ) {
              Some(value) if value < mask => Some(value)
              _ => Some(mask)
            }
          }
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
          let (mask, value_id) = match
            optimize_instructions_i64_const(func, dead, rhs_id) {
            Some(@lib.I64(raw)) => (raw, lhs_id)
            _ =>
              match optimize_instructions_i64_const(func, dead, lhs_id) {
                Some(@lib.I64(raw)) => (raw, rhs_id)
                _ => return None
              }
          }
          if mask < 0L {
            None
          } else {
            match
              OiUnsignedMaxValueFact::i64_max_for_node(
                func, dead, local_facts, value_id,
              ) {
              Some(value) if value < mask => Some(value)
              _ => Some(mask)
            }
          }
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
fn optimize_instructions_i64_unsigned_max_fact_for_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Int64? {
  OiUnsignedMaxValueFact::from_i64_value(func, dead, scratch, node_id).i64_max
}

///|
fn optimize_instructions_scan_unsigned_max_local_sets_region(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  region : @ir.HotRegionRef,
) -> Unit {
  for i = 0; i < @ir.hot_region_root_count(func, region); i = i + 1 {
    optimize_instructions_scan_unsigned_max_local_sets_expr(
      func,
      dead,
      scratch,
      @ir.hot_region_get(func, region, i),
    )
  }
}

///|
fn optimize_instructions_scan_unsigned_max_local_sets_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  scratch : OptimizeInstructionsScratch,
  node_id : Int,
) -> Unit {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    optimize_instructions_scan_unsigned_max_local_sets_expr(
      func,
      dead,
      scratch,
      func.children[node.child_base + slot],
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      optimize_instructions_scan_unsigned_max_local_sets_region(
        func,
        dead,
        scratch,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      optimize_instructions_scan_unsigned_max_local_sets_region(
        func,
        dead,
        scratch,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_scan_unsigned_max_local_sets_region(
            func, dead, scratch, else_region,
          )
        None => ()
      }
    }
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.child_count == 1 &&
      node.imm0 >= @ir.hot_local_param_count(func) =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(val_type) if val_type == @lib.ValType::i32() =>
          scratch.local_facts.merge_i32_unsigned_max_for_local(
            node.imm0,
            OiUnsignedMaxValueFact::from_assigned_i32_value(
              func,
              dead,
              func.children[node.child_base],
            ).i32_max,
          )
        Some(val_type) if val_type == @lib.ValType::i64() =>
          scratch.local_facts.merge_i64_unsigned_max_for_local(
            node.imm0,
            OiUnsignedMaxValueFact::from_assigned_i64_value(
              func,
              dead,
              func.children[node.child_base],
            ).i64_max,
          )
        _ => ()
      }
    _ => ()
  }
}

///|
fn optimize_instructions_scan_unsigned_max_facts(
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
    optimize_instructions_scan_unsigned_max_local_sets_expr(
      func,
      dead,
      scratch,
      func.roots[slot],
    )
  }
  scratch.local_facts.unsigned_max_ready = true
}

///|
fn optimize_instructions_node_is_live(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if node_id < 0 {
    return false
  }
  if node_id < dead.length() {
    return !dead[node_id]
  }
  @ir.hot_node_is_live(func, node_id)
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
fn optimize_instructions_node_is_i32_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_type_get(func, @ir.hot_node_get(func, node_id).ty) {
    @ir.HotTypeInfo::Value(val_type) => val_type == @lib.ValType::i32()
    _ => false
  }
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
}

///|
fn OiCallRefFallthroughTargetFact::unknown() -> OiCallRefFallthroughTargetFact {
  { direct_func: -1 }
}

///|
fn OiCallRefFallthroughTargetFact::from_node(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  depth? : Int = 0,
) -> OiCallRefFallthroughTargetFact {
  if depth > 8 || !optimize_instructions_node_is_live(func, dead, node_id) {
    return OiCallRefFallthroughTargetFact::unknown()
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::RefFunc => { direct_func: node.imm0 }
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
    _ => OiCallRefFallthroughTargetFact::unknown()
  }
}

///|
fn OiCallRefFallthroughTargetFact::has_direct_func(
  self : OiCallRefFallthroughTargetFact,
) -> Bool {
  self.direct_func >= 0
}

///|
priv struct OiCallRefTargetFact {
  direct_func : Int
  table_idx : Int
  table_index_id : Int
  fallthrough_func : Int
  select_true_func : Int
  select_false_func : Int
  select_condition_id : Int
}

///|
fn OiCallRefTargetFact::unknown() -> OiCallRefTargetFact {
  {
    direct_func: -1,
    table_idx: -1,
    table_index_id: -1,
    fallthrough_func: -1,
    select_true_func: -1,
    select_false_func: -1,
    select_condition_id: -1,
  }
}

///|
fn OiCallRefTargetFact::from_target(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  callee_ref_id : Int,
) -> OiCallRefTargetFact {
  if !optimize_instructions_node_is_live(func, dead, callee_ref_id) {
    return OiCallRefTargetFact::unknown()
  }
  let callee_ref = @ir.hot_node_get(func, callee_ref_id)
  match callee_ref.op {
    @ir.HotOp::RefFunc =>
      {
        direct_func: callee_ref.imm0,
        table_idx: -1,
        table_index_id: -1,
        fallthrough_func: -1,
        select_true_func: -1,
        select_false_func: -1,
        select_condition_id: -1,
      }
    @ir.HotOp::TableGet if callee_ref.child_count == 1 => {
      let table_index_id = @ir.hot_child_get(func, callee_ref_id, 0)
      if optimize_instructions_node_is_live(func, dead, table_index_id) {
        {
          direct_func: -1,
          table_idx: callee_ref.imm0,
          table_index_id,
          fallthrough_func: -1,
          select_true_func: -1,
          select_false_func: -1,
          select_condition_id: -1,
        }
      } else {
        OiCallRefTargetFact::unknown()
      }
    }
    @ir.HotOp::Block =>
      OiCallRefTargetFact::from_fallthrough_block(func, dead, callee_ref_id)
    @ir.HotOp::Select if callee_ref.child_count == 3 =>
      OiCallRefTargetFact::from_select(func, dead, callee_ref_id)
    _ => {
      let fallthrough = OiCallRefFallthroughTargetFact::from_node(
        func, dead, callee_ref_id,
      )
      if fallthrough.has_direct_func() {
        {
          direct_func: -1,
          table_idx: -1,
          table_index_id: -1,
          fallthrough_func: fallthrough.direct_func,
          select_true_func: -1,
          select_false_func: -1,
          select_condition_id: -1,
        }
      } else {
        OiCallRefTargetFact::unknown()
      }
    }
  }
}

///|
fn OiCallRefTargetFact::from_fallthrough_block(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  callee_ref_id : Int,
) -> OiCallRefTargetFact {
  let body_ref = @ir.hot_region_body_ref(func, callee_ref_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < 1 {
    return OiCallRefTargetFact::unknown()
  }
  let target_id = @ir.hot_region_get(func, body_ref, root_count - 1)
  if !optimize_instructions_node_is_live(func, dead, target_id) {
    return OiCallRefTargetFact::unknown()
  }
  let target = OiCallRefFallthroughTargetFact::from_node(func, dead, target_id)
  if target.has_direct_func() {
    {
      direct_func: -1,
      table_idx: -1,
      table_index_id: -1,
      fallthrough_func: target.direct_func,
      select_true_func: -1,
      select_false_func: -1,
      select_condition_id: -1,
    }
  } else {
    OiCallRefTargetFact::unknown()
  }
}

///|
priv struct OiCallRefSelectArmFact {
  direct_func : Int
}

///|
fn OiCallRefSelectArmFact::unknown() -> OiCallRefSelectArmFact {
  { direct_func: -1 }
}

///|
fn OiCallRefSelectArmFact::from_target_arm(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  arm_id : Int,
) -> OiCallRefSelectArmFact {
  if !optimize_instructions_node_is_live(func, dead, arm_id) {
    return OiCallRefSelectArmFact::unknown()
  }
  let arm = @ir.hot_node_get(func, arm_id)
  match arm.op {
    // Binaryen v130 `OptimizeInstructions::visitCallRef` passes
    // `CallUtils::convertToDirectCalls` a classifier whose only known target is
    // a direct `RefFunc`. Table targets, fallthrough targets, nested selects,
    // and descriptor producers intentionally stay out of this select-arm fact
    // until a source-backed helper proves the broader shape.
    @ir.HotOp::RefFunc => { direct_func: arm.imm0 }
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
fn OiCallRefTargetFact::from_select(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  callee_ref_id : Int,
) -> OiCallRefTargetFact {
  let true_ref_id = @ir.hot_child_get(func, callee_ref_id, 0)
  let false_ref_id = @ir.hot_child_get(func, callee_ref_id, 1)
  let condition_id = @ir.hot_child_get(func, callee_ref_id, 2)
  if !optimize_instructions_node_is_live(func, dead, condition_id) {
    return OiCallRefTargetFact::unknown()
  }
  let true_fact = OiCallRefSelectArmFact::from_target_arm(
    func, dead, true_ref_id,
  )
  let false_fact = OiCallRefSelectArmFact::from_target_arm(
    func, dead, false_ref_id,
  )
  if true_fact.has_direct_func() && false_fact.has_direct_func() {
    {
      direct_func: -1,
      table_idx: -1,
      table_index_id: -1,
      fallthrough_func: -1,
      select_true_func: true_fact.direct_func,
      select_false_func: false_fact.direct_func,
      select_condition_id: condition_id,
    }
  } else {
    OiCallRefTargetFact::unknown()
  }
}

///|
fn OiCallRefTargetFact::has_direct_func(self : OiCallRefTargetFact) -> Bool {
  self.direct_func >= 0
}

///|
fn OiCallRefTargetFact::has_table_target(self : OiCallRefTargetFact) -> Bool {
  self.table_idx >= 0 && self.table_index_id >= 0
}

///|
fn OiCallRefTargetFact::has_fallthrough_func(
  self : OiCallRefTargetFact,
) -> Bool {
  self.fallthrough_func >= 0
}

///|
fn OiCallRefTargetFact::has_select_direct_funcs(
  self : OiCallRefTargetFact,
) -> Bool {
  self.select_true_func >= 0 &&
  self.select_false_func >= 0 &&
  self.select_condition_id >= 0
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
fn OiCallRefOperandFact::args_with_fallthrough_target_after_last_operand(
  self : OiCallRefOperandFact,
  func : @ir.HotFunc,
  callee_ref_id : Int,
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
        @ir.hot_build_drop(func, callee_ref_id),
        @ir.hot_build_local_get(func, temp_local),
      ],
    ),
  )
  Some(operands)
}

///|
fn optimize_instructions_call_ref_result_block_type(
  func : @ir.HotFunc,
  node : @ir.HotNode,
) -> @lib.BlockType? {
  let results = @ir.hot_type_results(func, node.ty)
  match results.length() {
    0 => Some(@lib.BlockType::void_())
    1 => Some(@lib.BlockType::val_type(results[0]))
    _ => None
  }
}

///|
fn optimize_instructions_try_directize_fallthrough_ref_func_call_ref(
  func : @ir.HotFunc,
  node : @ir.HotNode,
  callee_ref_id : Int,
  target_fact : OiCallRefTargetFact,
  operand_fact : OiCallRefOperandFact,
) -> Int? {
  if !target_fact.has_fallthrough_func() {
    return None
  }
  match node.op {
    @ir.HotOp::CallRef => {
      let block_type = match
        optimize_instructions_call_ref_result_block_type(func, node) {
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
              @ir.hot_build_call(func, target_fact.fallthrough_func, results, []),
            ]),
          )
        Some(operands) =>
          Some(
            @ir.hot_build_call(
              func,
              target_fact.fallthrough_func,
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
              @ir.hot_build_return_call(func, target_fact.fallthrough_func, []),
            ]),
          )
        Some(operands) =>
          Some(
            @ir.hot_build_return_call(
              func,
              target_fact.fallthrough_func,
              operands,
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
priv enum OiCallRefDirectizePlanKind {
  CallRefDirectFunc
  CallRefTableTarget
  CallRefFallthroughFunc
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
      optimize_instructions_try_directize_fallthrough_ref_func_call_ref(
        func,
        node,
        callee_ref_id,
        self.target_fact,
        operand_fact,
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
fn OiCallRefDirectizePlanFact::build_select_direct_funcs_replacement(
  self : OiCallRefDirectizePlanFact,
  func : @ir.HotFunc,
  node : @ir.HotNode,
  operand_fact : OiCallRefOperandFact,
) -> Int? {
  let block_type = match node.op {
    @ir.HotOp::CallRef =>
      match optimize_instructions_call_ref_result_block_type(func, node) {
        Some(block_type) => block_type
        None => return None
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
        self.target_fact.select_condition_id,
        [
          @ir.hot_build_call(
            func,
            self.target_fact.select_true_func,
            @ir.hot_type_results(func, node.ty),
            localized_operands.local_gets(func),
          ),
        ],
        else_body=Some([
          @ir.hot_build_call(
            func,
            self.target_fact.select_false_func,
            @ir.hot_type_results(func, node.ty),
            localized_operands.local_gets(func),
          ),
        ]),
      )
    @ir.HotOp::ReturnCallRef =>
      @ir.hot_build_if(
        func,
        @lib.BlockType::void_(),
        self.target_fact.select_condition_id,
        [
          @ir.hot_build_return_call(
            func,
            self.target_fact.select_true_func,
            localized_operands.local_gets(func),
          ),
        ],
        else_body=Some([
          @ir.hot_build_return_call(
            func,
            self.target_fact.select_false_func,
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
fn optimize_instructions_try_directize_ref_func_call_ref(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::CallRef | @ir.HotOp::ReturnCallRef => ()
    _ => return false
  }
  if node.child_count < 1 {
    return false
  }
  let callee_ref_id = @ir.hot_child_get(func, node_id, node.child_count - 1)
  if !optimize_instructions_node_is_live(func, dead, callee_ref_id) {
    return false
  }
  let target_fact = OiCallRefTargetFact::from_target(func, dead, callee_ref_id)
  let args : Array[Int] = []
  for slot = 0; slot < node.child_count - 1; slot = slot + 1 {
    args.push(@ir.hot_child_get(func, node_id, slot))
  }
  let plan_fact = match
    OiCallRefDirectizePlanFact::from_target(func, target_fact, args) {
    Some(fact) => fact
    None => return false
  }
  let temp = match
    plan_fact.build_replacement(func, node, callee_ref_id, args) {
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
fn optimize_instructions_try_sink_same_global_set_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, then_set_id) ||
    !optimize_instructions_node_is_live(func, dead, else_set_id) {
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
  if !optimize_instructions_is_side_effect_free_expr(func, dead, then_value) ||
    !optimize_instructions_is_side_effect_free_expr(func, dead, else_value) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
  if !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
fn optimize_instructions_i32_non_negative_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(raw)) => raw >= 0
    None => false
  }
}

///|
fn optimize_instructions_i64_non_negative_const(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match optimize_instructions_i64_const(func, dead, node_id) {
    Some(@lib.I64(raw)) => raw >= 0L
    None => false
  }
}

///|
fn optimize_instructions_signed_const_unsigned_variant(
  instr : @lib.Instruction,
) -> @lib.Instruction? {
  match instr {
    @lib.Instruction::I32LtS => Some(@lib.Instruction::i32_lt_u())
    @lib.Instruction::I32GtS => Some(@lib.Instruction::i32_gt_u())
    @lib.Instruction::I32LeS => Some(@lib.Instruction::i32_le_u())
    @lib.Instruction::I32GeS => Some(@lib.Instruction::i32_ge_u())
    @lib.Instruction::I32DivS => Some(@lib.Instruction::i32_div_u())
    @lib.Instruction::I32RemS => Some(@lib.Instruction::i32_rem_u())
    @lib.Instruction::I32ShrS => Some(@lib.Instruction::i32_shr_u())
    @lib.Instruction::I64LtS => Some(@lib.Instruction::i64_lt_u())
    @lib.Instruction::I64GtS => Some(@lib.Instruction::i64_gt_u())
    @lib.Instruction::I64LeS => Some(@lib.Instruction::i64_le_u())
    @lib.Instruction::I64GeS => Some(@lib.Instruction::i64_ge_u())
    @lib.Instruction::I64DivS => Some(@lib.Instruction::i64_div_u())
    @lib.Instruction::I64RemS => Some(@lib.Instruction::i64_rem_u())
    @lib.Instruction::I64ShrS => Some(@lib.Instruction::i64_shr_u())
    _ => None
  }
}

///|
fn optimize_instructions_try_canonicalize_signed_const_unsigned(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  let unsigned_instr = match
    optimize_instructions_signed_const_unsigned_variant(instr) {
    Some(unsigned_instr) => unsigned_instr
    None => return false
  }
  let operands_are_non_negative = match instr {
    @lib.Instruction::I32LtS
    | @lib.Instruction::I32GtS
    | @lib.Instruction::I32LeS
    | @lib.Instruction::I32GeS
    | @lib.Instruction::I32DivS
    | @lib.Instruction::I32RemS =>
      optimize_instructions_i32_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i32_non_negative_const(func, dead, rhs_id)
    @lib.Instruction::I32ShrS =>
      optimize_instructions_i32_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i32_non_negative_const(func, dead, rhs_id)
    @lib.Instruction::I64LtS
    | @lib.Instruction::I64GtS
    | @lib.Instruction::I64LeS
    | @lib.Instruction::I64GeS
    | @lib.Instruction::I64DivS
    | @lib.Instruction::I64RemS =>
      optimize_instructions_i64_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i64_non_negative_const(func, dead, rhs_id)
    @lib.Instruction::I64ShrS =>
      optimize_instructions_i64_non_negative_const(func, dead, lhs_id) &&
      optimize_instructions_i64_non_negative_const(func, dead, rhs_id)
    _ => false
  }
  if !operands_are_non_negative {
    return false
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
fn optimize_instructions_i32_mask_is_low_ones(raw : Int) -> Bool {
  raw >= 0 && (raw & (raw + 1)) == 0
}

///|
fn optimize_instructions_i64_mask_is_low_ones(raw : Int64) -> Bool {
  raw >= 0L && (raw & (raw + 1L)) == 0L
}

///|
fn optimize_instructions_is_commutative_instr(instr : @lib.Instruction) -> Bool {
  match instr {
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
}

///|
fn optimize_instructions_local_get_id(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return None
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet => Some(node.imm0)
    _ => None
  }
}

///|
fn optimize_instructions_is_constlike(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn optimize_instructions_is_shared_cross_safe_leaf(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn optimize_instructions_can_cross_local_get(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
  local_id : Int,
  under_local_tee_payload : Bool,
  loop_input_nodes : @bitset.BitSet,
  seen_stamps : Array[Int],
  seen_stamp : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return true
  }
  if node_id < seen_stamps.length() && seen_stamps[node_id] == seen_stamp {
    return true
  }
  if node_id < seen_stamps.length() {
    seen_stamps[node_id] = seen_stamp
  }
  if node_id < loop_input_nodes.length() && loop_input_nodes[node_id] {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::If => ()
    @ir.HotOp::Block => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      match @ir.hot_label_kind(func, label_id) {
        @ir.HotLabelKind::RegionLabel => ()
        _ => return false
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
    | @ir.HotOp::CatchAll => return false
    _ => ()
  }
  if @ir.node_use_count(use_def, node_id) > 1 {
    if !optimize_instructions_is_shared_cross_safe_leaf(func, dead, node_id) ||
      under_local_tee_payload {
      return false
    }
  }
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.imm0 == local_id =>
      return false
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_is_local_tee_payload = match node.op {
      @ir.HotOp::LocalTee => slot == 0
      _ => false
    }
    if !optimize_instructions_can_cross_local_get(
        func,
        dead,
        use_def,
        func.children[node.child_base + slot],
        local_id,
        child_is_local_tee_payload,
        loop_input_nodes,
        seen_stamps,
        seen_stamp,
      ) {
      return false
    }
  }
  true
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
  if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
    !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
  if !optimize_instructions_can_swap_leading_operands(ctx, func, lhs_id, rhs_id) {
    return false
  }
  optimize_instructions_rewrite_exact_with_children(ctx, func, node_id, instr, [
    rhs_id, lhs_id,
  ])
  true
}

///|
fn optimize_instructions_is_trivially_pure_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn optimize_instructions_is_trivially_pure_value(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  optimize_instructions_node_is_live(func, dead, node_id) &&
  optimize_instructions_is_trivially_pure_operand(func, node_id)
}

///|
fn optimize_instructions_is_side_effect_free_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = if node_id < func.nodes.length() {
    func.nodes[node_id]
  } else {
    @ir.hot_node_get(func, node_id)
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefNull(_)) => return true
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
      )
    ) => return true
    Some(@lib.Instruction::RefI31) if node.child_count == 1 =>
      return optimize_instructions_is_side_effect_free_expr(
        func,
        dead,
        func.children[node.child_base],
      )
    Some(instr) if node.child_count == 1 &&
      (
        instr == @lib.Instruction::i8x16_splat() ||
        instr == @lib.Instruction::i16x8_splat() ||
        instr == @lib.Instruction::i32x4_splat() ||
        instr == @lib.Instruction::i64x2_splat() ||
        instr == @lib.Instruction::f32x4_splat() ||
        instr == @lib.Instruction::f64x2_splat()
      ) =>
      return optimize_instructions_is_side_effect_free_expr(
        func,
        dead,
        func.children[node.child_base],
      )
    _ => ()
  }
  match node.op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !optimize_instructions_is_side_effect_free_expr(
            func,
            dead,
            func.children[node.child_base + slot],
          ) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_negate_boolean_expr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Int? {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
fn optimize_instructions_is_boolean_constant_tree(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(0)) | Some(@lib.I32(1)) => return true
    _ => ()
  }
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ => return false
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
  optimize_instructions_is_boolean_constant_tree(
    func,
    dead,
    @ir.hot_region_get(func, then_region, 0),
  ) &&
  optimize_instructions_is_boolean_constant_tree(
    func,
    dead,
    @ir.hot_region_get(func, else_region, 0),
  )
}

///|
fn optimize_instructions_boolean_tree_if_nodes_are_unshared(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  use_def : @ir.HotUseDef,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::I32Eqz) if @ir.hot_child_count(func, node_id) == 1 =>
      return true
    _ => ()
  }
  match optimize_instructions_i32_const(func, dead, node_id) {
    Some(@lib.I32(0)) | Some(@lib.I32(1)) => return true
    _ => ()
  }
  if @ir.node_use_count(use_def, node_id) > 1 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => ()
    _ => return false
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
  optimize_instructions_boolean_tree_if_nodes_are_unshared(
    func,
    dead,
    use_def,
    @ir.hot_region_get(func, then_region, 0),
  ) &&
  optimize_instructions_boolean_tree_if_nodes_are_unshared(
    func,
    dead,
    use_def,
    @ir.hot_region_get(func, else_region, 0),
  )
}

///|
fn optimize_instructions_same_branch_shape(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
    !optimize_instructions_node_is_live(func, dead, rhs_id) {
    return false
  }
  let lhs = @ir.hot_node_get(func, lhs_id)
  let rhs = @ir.hot_node_get(func, rhs_id)
  match (lhs.op, rhs.op) {
    (@ir.HotOp::Br, @ir.HotOp::Br) if lhs.imm0 == rhs.imm0 &&
      lhs.child_count == rhs.child_count => {
      for slot = 0; slot < lhs.child_count; slot = slot + 1 {
        if @ir.hot_child_get(func, lhs_id, slot) !=
          @ir.hot_child_get(func, rhs_id, slot) {
          return false
        }
      }
      true
    }
    _ => false
  }
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
  if !optimize_instructions_is_side_effect_free_expr(func, dead, inner_cond_id) {
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
fn optimize_instructions_node_is_zero_sentinel(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      @ir.hot_const_get(func, node.imm0) ==
      @ir.HotConstPayload::i32_const(@lib.I32(0))
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) != 1 {
        false
      } else {
        optimize_instructions_node_is_zero_sentinel(
          func,
          @ir.hot_child_get(func, node_id, 0),
        )
      }
    _ => false
  }
}

///|
fn optimize_instructions_node_is_drop_zero_sentinel(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop =>
      @ir.hot_child_count(func, node_id) == 1 &&
      optimize_instructions_node_is_zero_sentinel(
        func,
        @ir.hot_child_get(func, node_id, 0),
      )
    _ => false
  }
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
fn optimize_instructions_region_exits_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_exits_to_label(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
}

///|
fn optimize_instructions_region_never_falls_through(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_never_falls_through(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
  )
}

///|
fn optimize_instructions_branch_table_targets_label(
  func : @ir.HotFunc,
  table_id : Int,
  label_id : Int,
) -> Bool {
  if @ir.hot_branch_table_default_target(func, table_id) != label_id {
    return false
  }
  for target in @ir.hot_branch_table_targets(func, table_id) {
    if target != label_id {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_node_never_falls_through(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate
    | @ir.HotOp::Br
    | @ir.HotOp::BrTable => true
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_never_falls_through(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
          ) &&
          optimize_instructions_region_never_falls_through(
            func, dead, else_region,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_never_falls_through_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_never_falls_through_to_label(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
}

///|
fn optimize_instructions_node_never_falls_through_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Br => node.imm0 == label_id
    @ir.HotOp::BrTable =>
      optimize_instructions_branch_table_targets_label(
        func,
        node.imm0,
        label_id,
      )
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_never_falls_through_to_label(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
            label_id,
          ) &&
          optimize_instructions_region_never_falls_through_to_label(
            func, dead, else_region, label_id,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_node_exits_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Br => node.imm0 == label_id
    @ir.HotOp::BrTable =>
      optimize_instructions_branch_table_targets_label(
        func,
        node.imm0,
        label_id,
      )
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_exits_to_label(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
            label_id,
          ) &&
          optimize_instructions_region_exits_to_label(
            func, dead, else_region, label_id,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_exits_only_via_branches(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_exits_only_via_branches(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
  )
}

///|
fn optimize_instructions_node_exits_only_via_branches(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrTable => true
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_exits_only_via_branches(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
          ) &&
          optimize_instructions_region_exits_only_via_branches(
            func, dead, else_region,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_node_branches_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  label_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => node.imm0 == label_id
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_branches_to_label(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
            label_id,
          ) &&
          optimize_instructions_region_branches_to_label(
            func, dead, else_region, label_id,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_branches_to_label(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
  label_id : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  optimize_instructions_node_branches_to_label(
    func,
    dead,
    @ir.hot_region_get(func, region_ref, root_count - 1),
    label_id,
  )
}

///|
fn optimize_instructions_node_exits_via_nonbranch_terminal(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Block =>
      optimize_instructions_region_exits_via_nonbranch_terminal(
        func,
        dead,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          optimize_instructions_region_exits_via_nonbranch_terminal(
            func,
            dead,
            @ir.hot_region_then_ref(func, node_id),
          ) &&
          optimize_instructions_region_exits_via_nonbranch_terminal(
            func, dead, else_region,
          )
        None => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_region_exits_via_nonbranch_terminal(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  for idx = 0; idx < root_count; idx = idx + 1 {
    let root = @ir.hot_region_get(func, region_ref, idx)
    if !optimize_instructions_node_is_live(func, dead, root) {
      continue
    }
    if optimize_instructions_node_exits_via_nonbranch_terminal(func, dead, root) {
      return true
    }
    if optimize_instructions_node_never_falls_through(func, dead, root) {
      return false
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
    let branch_only_if_escape = match root_op {
      @ir.HotOp::If =>
        optimize_instructions_node_exits_only_via_branches(func, dead, root)
      _ => false
    }
    let direct_terminal = match root_op {
      @ir.HotOp::Br
      | @ir.HotOp::BrTable
      | @ir.HotOp::Unreachable
      | @ir.HotOp::Return
      | @ir.HotOp::Throw
      | @ir.HotOp::Rethrow
      | @ir.HotOp::ThrowRef
      | @ir.HotOp::Delegate => true
      _ => false
    }
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
      optimize_instructions_node_never_falls_through_to_label(
        func, dead, root, label_id,
      )
    } else {
      optimize_instructions_node_never_falls_through(func, dead, root)
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
        _ =>
          optimize_instructions_node_exits_to_label(func, dead, root, label_id) ||
          never_falls_through
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
        optimize_instructions_node_is_drop_zero_sentinel(func, tail_id) {
        return false
      }
      let root_is_result_carrier = match root_op {
        @ir.HotOp::If | @ir.HotOp::Block => true
        _ => false
      }
      let keep_result_zero_sentinel = root_is_result_carrier &&
        optimize_instructions_node_exits_via_nonbranch_terminal(
          func, dead, root,
        )
      if optimize_instructions_node_is_zero_sentinel(func, tail_id) &&
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
              !optimize_instructions_node_exits_to_label(
                func,
                dead,
                root,
                tail.imm0,
              ) {
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
  if !optimize_instructions_is_constlike(func, dead, lhs_id) ||
    optimize_instructions_is_constlike(func, dead, rhs_id) {
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
    optimize_instructions_local_get_id(func, dead, lhs_id) {
    Some(local_id) => {
      if optimize_instructions_is_constlike(func, dead, rhs_id) {
        return false
      }
      let should_swap = match
        optimize_instructions_local_get_id(func, dead, rhs_id) {
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
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        use_def,
        rhs_id,
        local_id,
        false,
        scratch.loop_input_nodes,
        scratch.cross_seen_stamps,
        seen_stamp,
      )
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
  match optimize_instructions_local_get_id(func, dead, rhs_id) {
    Some(local_id) => {
      if optimize_instructions_is_constlike(func, dead, lhs_id) ||
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
      let can_cross = optimize_instructions_can_cross_local_get(
        func,
        dead,
        use_def,
        lhs_id,
        local_id,
        false,
        scratch.loop_input_nodes,
        scratch.cross_seen_stamps,
        seen_stamp,
      )
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
          optimize_instructions_node_is_i32_value(func, lhs_id) => {
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
        Some(operand_id) if optimize_instructions_node_is_i32_value(
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
      if !optimize_instructions_node_is_i32_value(func, operand_id) {
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
  if optimize_instructions_is_boolean_constant_tree(func, dead, then_root) &&
    optimize_instructions_is_boolean_constant_tree(func, dead, else_root) {
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
priv struct OiLeftFallthroughInputFact {
  fallthrough_id : Int
  after_value_effect_mask : UInt
  after_value_write_mask : UInt
  after_value_local_writes : Array[Int]
  after_value_global_writes : Array[Int]
  unsupported_after_value_control : Bool
}

///|
priv struct OiRightFallthroughInputFact {
  fallthrough_id : Int
  prefix_effect_mask : UInt
  prefix_write_mask : UInt
  prefix_local_writes : Array[Int]
  prefix_global_writes : Array[Int]
  unsupported_prefix_control : Bool
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
  intervening_effects_interfere : Bool
}

///|
fn optimize_instructions_local_writes_append_unique(
  writes : Array[Int],
  local_idx : Int,
) -> Unit {
  for value in writes {
    if value == local_idx {
      return
    }
  }
  writes.push(local_idx)
}

///|
fn optimize_instructions_global_writes_append_unique(
  writes : Array[Int],
  global_idx : Int,
) -> Unit {
  for value in writes {
    if value == global_idx {
      return
    }
  }
  writes.push(global_idx)
}

///|
fn optimize_instructions_subtree_local_writes(
  func : @ir.HotFunc,
  node_id : Int,
) -> Array[Int] {
  let writes : Array[Int] = []
  fn walk(id : Int) -> Unit {
    let node = @ir.hot_node_get(func, id)
    match node.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
        optimize_instructions_local_writes_append_unique(writes, node.imm0)
      _ => ()
    }
    for slot = 0; slot < @ir.hot_child_count(func, id); slot = slot + 1 {
      walk(@ir.hot_child_get(func, id, slot))
    }
  }
  walk(node_id)
  writes
}

///|
fn optimize_instructions_subtree_global_writes(
  func : @ir.HotFunc,
  node_id : Int,
) -> Array[Int] {
  let writes : Array[Int] = []
  fn walk(id : Int) -> Unit {
    let node = @ir.hot_node_get(func, id)
    match node.op {
      @ir.HotOp::GlobalSet =>
        optimize_instructions_global_writes_append_unique(writes, node.imm0)
      _ => ()
    }
    for slot = 0; slot < @ir.hot_child_count(func, id); slot = slot + 1 {
      walk(@ir.hot_child_get(func, id, slot))
    }
  }
  walk(node_id)
  writes
}

///|
fn optimize_instructions_append_local_writes(
  dst : Array[Int],
  src : Array[Int],
) -> Unit {
  for local_idx in src {
    optimize_instructions_local_writes_append_unique(dst, local_idx)
  }
}

///|
fn optimize_instructions_append_global_writes(
  dst : Array[Int],
  src : Array[Int],
) -> Unit {
  for global_idx in src {
    optimize_instructions_global_writes_append_unique(dst, global_idx)
  }
}

///|
fn optimize_instructions_local_writes_include(
  writes : Array[Int],
  local_idx : Int,
) -> Bool {
  for value in writes {
    if value == local_idx {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_global_writes_include(
  writes : Array[Int],
  global_idx : Int,
) -> Bool {
  for value in writes {
    if value == global_idx {
      return true
    }
  }
  false
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
fn optimize_instructions_is_pure_scalar_equal_tree_op(op : @ir.HotOp) -> Bool {
  // Source-mapped subset of Binaryen v130 `ExpressionAnalyzer::equal` used by
  // OI's consecutive-input equality facts: branchless scalar expression shells
  // whose children are recursively deterministic under the enclosing ordered-
  // effects check.
  match op {
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select => true
    _ => false
  }
}

///|
fn optimize_instructions_stable_state_reads_equal(
  left : @ir.HotNode,
  right : @ir.HotNode,
) -> Bool {
  // Binaryen v130 `areConsecutiveInputsEqual` reaches
  // `ExpressionAnalyzer::equal` after fallthrough peeling. Deterministic state
  // reads with the same index compare equal there, but only after the enclosing
  // equality fact has checked that intervening effects are not ordered before
  // the right read. Keep this fact separate from `matching_pure_scalar_tree` so
  // state reads remain visible as effect-sensitive equality, not pure values.
  match (left.op, right.op) {
    (@ir.HotOp::MemorySize, @ir.HotOp::MemorySize) => left.imm0 == right.imm0
    (@ir.HotOp::TableSize, @ir.HotOp::TableSize) => left.imm0 == right.imm0
    _ => false
  }
}

///|
fn optimize_instructions_exact_instr_is_stable_atomic_memory_read(
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
fn optimize_instructions_stable_memory_read_ops_equal(
  left_op : @ir.HotOp,
  right_op : @ir.HotOp,
  left_instr : @lib.Instruction,
  right_instr : @lib.Instruction,
) -> Bool {
  match (left_op, right_op) {
    (@ir.HotOp::Load, @ir.HotOp::Load) => left_instr == right_instr
    (@ir.HotOp::Atomic, @ir.HotOp::Atomic) =>
      left_instr == right_instr &&
      optimize_instructions_exact_instr_is_stable_atomic_memory_read(left_instr)
    _ => false
  }
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
    !optimize_instructions_is_pure_scalar_equal_tree_op(left.op) ||
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
fn optimize_instructions_stable_memory_read_address_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  depth? : Int = 0,
) -> Bool {
  if depth > 16 {
    return false
  }
  let left = @ir.hot_node_get(func, left_id)
  let right = @ir.hot_node_get(func, right_id)
  if optimize_instructions_stable_state_reads_equal(left, right) {
    return true
  }
  match (left.op, right.op) {
    (@ir.HotOp::LocalGet, @ir.HotOp::LocalGet) => left.imm0 == right.imm0
    (@ir.HotOp::GlobalGet, @ir.HotOp::GlobalGet) => left.imm0 == right.imm0
    (@ir.HotOp::Const, @ir.HotOp::Const) =>
      @ir.hot_const_get(func, left.imm0) == @ir.hot_const_get(func, right.imm0)
    _ => {
      if !optimize_instructions_scalar_tree_metadata_equal(
          func, left_id, right_id, left, right,
        ) {
        return false
      }
      for slot = 0; slot < left.child_count; slot = slot + 1 {
        if !optimize_instructions_stable_memory_read_address_equal(
            func,
            @ir.hot_child_get(func, left_id, slot),
            @ir.hot_child_get(func, right_id, slot),
            depth=depth + 1,
          ) {
          return false
        }
      }
      true
    }
  }
}

///|
fn optimize_instructions_stable_state_scalar_tree_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
) -> Bool {
  // Binaryen v130 `ExpressionAnalyzer::equal` treats scalar trees containing
  // deterministic state-read leaves as equal, but the enclosing
  // `areConsecutiveInputsEqual` fact must still check intervening effects before
  // the right tree. Keep this separate from pure scalar equality so memory/table
  // growth boundaries remain effect-sensitive.
  !optimize_instructions_pure_scalar_tree_equal(func, left_id, right_id) &&
  optimize_instructions_stable_memory_read_address_equal(
    func, left_id, right_id,
  )
}

///|
fn optimize_instructions_stable_memory_reads_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
) -> Bool {
  // Binaryen v130 `areConsecutiveInputsEqual` delegates to
  // `ExpressionAnalyzer::equal` after fallthrough peeling, then separately asks
  // `EffectAnalyzer::orderedBefore(effects(right))` whether intervening effects
  // can change the right read. Model the represented load subset as an explicit
  // effect-sensitive fact: same load/atomic-load instruction, same access
  // metadata, and a source-backed address proof for pure scalar trees plus
  // deterministic state-read leaves. The enclosing equality fact still owns the
  // memory/state-write interference check, so store/grow prefixes keep the copy
  // live.
  let left = @ir.hot_node_get(func, left_id)
  let right = @ir.hot_node_get(func, right_id)
  if left.child_count != 1 || right.child_count != 1 {
    return false
  }
  match
    (
      @ir.hot_node_exact_instr(func, left_id),
      @ir.hot_node_exact_instr(func, right_id),
    ) {
    (Some(left_instr), Some(right_instr)) if optimize_instructions_stable_memory_read_ops_equal(
        left.op,
        right.op,
        left_instr,
        right_instr,
      ) =>
      optimize_instructions_stable_memory_read_address_equal(
        func,
        @ir.hot_child_get(func, left_id, 0),
        @ir.hot_child_get(func, right_id, 0),
      )
    _ => false
  }
}

///|
fn optimize_instructions_pure_scalar_tree_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  depth? : Int = 0,
) -> Bool {
  if depth > 16 {
    return false
  }
  let left = @ir.hot_node_get(func, left_id)
  let right = @ir.hot_node_get(func, right_id)
  match (left.op, right.op) {
    (@ir.HotOp::LocalGet, @ir.HotOp::LocalGet) => left.imm0 == right.imm0
    (@ir.HotOp::GlobalGet, @ir.HotOp::GlobalGet) => left.imm0 == right.imm0
    (@ir.HotOp::Const, @ir.HotOp::Const) =>
      @ir.hot_const_get(func, left.imm0) == @ir.hot_const_get(func, right.imm0)
    _ => {
      if !optimize_instructions_scalar_tree_metadata_equal(
          func, left_id, right_id, left, right,
        ) {
        return false
      }
      for slot = 0; slot < left.child_count; slot = slot + 1 {
        if !optimize_instructions_pure_scalar_tree_equal(
            func,
            @ir.hot_child_get(func, left_id, slot),
            @ir.hot_child_get(func, right_id, slot),
            depth=depth + 1,
          ) {
          return false
        }
      }
      true
    }
  }
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
            after_value_local_writes: [],
            after_value_global_writes: [],
            unsupported_after_value_control: false,
          }
        _ => ()
      }
      let child_id = @ir.hot_child_get(func, node_id, 0)
      let nested = optimize_instructions_left_fallthrough_input_for_equality(
        func, node_masks, child_id, right_fallthrough_id,
      )
      let local_writes : Array[Int] = []
      optimize_instructions_append_local_writes(
        local_writes,
        nested.after_value_local_writes,
      )
      optimize_instructions_local_writes_append_unique(local_writes, node.imm0)
      let global_writes : Array[Int] = []
      optimize_instructions_append_global_writes(
        global_writes,
        nested.after_value_global_writes,
      )
      {
        fallthrough_id: nested.fallthrough_id,
        after_value_effect_mask: nested.after_value_effect_mask |
        @ir.EFFECT_MASK_LOCAL_STATE,
        after_value_write_mask: nested.after_value_write_mask |
        @ir.EFFECT_MASK_LOCAL_STATE,
        after_value_local_writes: local_writes,
        after_value_global_writes: global_writes,
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
        after_value_local_writes: [],
        after_value_global_writes: [],
        unsupported_after_value_control: true,
      }
    _ =>
      {
        fallthrough_id: node_id,
        after_value_effect_mask: 0U,
        after_value_write_mask: 0U,
        after_value_local_writes: [],
        after_value_global_writes: [],
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
      let prefix_local_writes : Array[Int] = []
      let prefix_global_writes : Array[Int] = []
      for slot = 0; slot < node.child_count - 1; slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        let child_mask = node_masks[child_id]
        if (child_mask & @ir.EFFECT_MASK_CONTROL) != 0U {
          return {
            fallthrough_id: node_id,
            prefix_effect_mask: 0U,
            prefix_write_mask: 0U,
            prefix_local_writes: [],
            prefix_global_writes: [],
            unsupported_prefix_control: true,
          }
        }
        prefix_effect_mask = prefix_effect_mask | child_mask
        prefix_write_mask = prefix_write_mask |
          optimize_instructions_subtree_write_mask(func, node_masks, child_id)
        optimize_instructions_append_local_writes(
          prefix_local_writes,
          optimize_instructions_subtree_local_writes(func, child_id),
        )
        optimize_instructions_append_global_writes(
          prefix_global_writes,
          optimize_instructions_subtree_global_writes(func, child_id),
        )
      }
      let nested = optimize_instructions_right_fallthrough_input_for_equality(
        func,
        node_masks,
        @ir.hot_child_get(func, node_id, node.child_count - 1),
      )
      optimize_instructions_append_local_writes(
        prefix_local_writes,
        nested.prefix_local_writes,
      )
      optimize_instructions_append_global_writes(
        prefix_global_writes,
        nested.prefix_global_writes,
      )
      {
        fallthrough_id: nested.fallthrough_id,
        prefix_effect_mask: prefix_effect_mask | nested.prefix_effect_mask,
        prefix_write_mask: prefix_write_mask | nested.prefix_write_mask,
        prefix_local_writes,
        prefix_global_writes,
        unsupported_prefix_control: nested.unsupported_prefix_control,
      }
    }
    _ =>
      {
        fallthrough_id: node_id,
        prefix_effect_mask: 0U,
        prefix_write_mask: 0U,
        prefix_local_writes: [],
        prefix_global_writes: [],
        unsupported_prefix_control: false,
      }
  }
}

///|
fn optimize_instructions_effects_ordered_before_right_fallthrough(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  effect_mask : UInt,
  write_mask : UInt,
  local_writes : Array[Int],
  global_writes : Array[Int],
  right_id : Int,
) -> Bool {
  let right_mask = node_masks[right_id]
  let right_write_mask = optimize_instructions_subtree_write_mask(
    func, node_masks, right_id,
  )
  let read_bits = optimize_instructions_reorder_read_effects()
  let mut effect_reads = effect_mask & read_bits
  let mut effective_write_mask = write_mask
  let mut right_reads = right_mask & read_bits
  let mut effective_right_write_mask = right_write_mask
  let right = @ir.hot_node_get(func, right_id)
  match right.op {
    @ir.HotOp::LocalGet if !optimize_instructions_local_writes_include(
        local_writes,
        right.imm0,
      ) => {
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
    @ir.HotOp::GlobalGet if (effect_mask & @ir.EFFECT_MASK_CALL) == 0U &&
      !optimize_instructions_global_writes_include(global_writes, right.imm0) => {
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
      effect_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)
    ) !=
    0U
  let right_side_effect = right_write_mask != 0U ||
    (right_mask & @ir.EFFECT_MASK_THROW) != 0U
  effects_disrupt && right_side_effect
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
  let matching_pure_scalar_tree = optimize_instructions_pure_scalar_tree_equal(
    func, left_fallthrough_id, right_fallthrough_id,
  )
  let matching_stable_state_read = optimize_instructions_stable_state_reads_equal(
    left, right,
  )
  let matching_stable_state_scalar_tree = optimize_instructions_stable_state_scalar_tree_equal(
    func, left_fallthrough_id, right_fallthrough_id,
  )
  let matching_stable_memory_read = optimize_instructions_stable_memory_reads_equal(
    func, left_fallthrough_id, right_fallthrough_id,
  )
  let intervening_local_writes : Array[Int] = []
  optimize_instructions_append_local_writes(
    intervening_local_writes,
    left_fallthrough.after_value_local_writes,
  )
  optimize_instructions_append_local_writes(
    intervening_local_writes,
    right_fallthrough.prefix_local_writes,
  )
  let intervening_global_writes : Array[Int] = []
  optimize_instructions_append_global_writes(
    intervening_global_writes,
    left_fallthrough.after_value_global_writes,
  )
  optimize_instructions_append_global_writes(
    intervening_global_writes,
    right_fallthrough.prefix_global_writes,
  )
  let intervening_effects_interfere = left_fallthrough.unsupported_after_value_control ||
    right_fallthrough.unsupported_prefix_control ||
    optimize_instructions_effects_ordered_before_right_fallthrough(
      func,
      effects.node_masks,
      left_fallthrough.after_value_effect_mask |
      right_fallthrough.prefix_effect_mask,
      left_fallthrough.after_value_write_mask |
      right_fallthrough.prefix_write_mask,
      intervening_local_writes,
      intervening_global_writes,
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
    self.matching_stable_memory_read {
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
  if !optimize_instructions_node_is_live(func, dead, self.value_id) {
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
  if !optimize_instructions_node_is_live(func, dead, self.value_id) {
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
  if !optimize_instructions_node_is_live(func, dead, self.value_id) {
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
  if !optimize_instructions_node_is_live(func, dead, load_id) ||
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
    if !optimize_instructions_node_is_live(func, dead, operand) ||
      !optimize_instructions_is_side_effect_free_expr(func, dead, operand) {
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
  if !optimize_instructions_is_side_effect_free_expr(func, dead, value_id) {
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
  if !optimize_instructions_is_side_effect_free_expr(func, dead, expected_id) ||
    !optimize_instructions_is_side_effect_free_expr(func, dead, replacement_id) {
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
  if !optimize_instructions_node_is_live(func, dead, tuple_id) ||
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
/// Binaryen version_130 keeps fresh array lengths above this O4z-observed
/// limit to preserve allocation trap behavior.
fn optimize_instructions_array_new_len_is_known_non_trapping(len : Int) -> Bool {
  len >= 0 && len <= 44739241
}

///|
fn optimize_instructions_forward_selected_operand_has_control_shape(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
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
    | @ir.HotOp::CatchAll => true
    _ => false
  }
}

///|
fn optimize_instructions_forward_selected_operand_append_discard(
  func : @ir.HotFunc,
  child_id : Int,
  child_results : Array[@lib.ValType],
  body : Array[Int],
) -> Bool {
  match child_results.length() {
    0 => body.push(child_id)
    1 => body.push(@ir.hot_build_drop(func, child_id))
    _ => return false
  }
  true
}

///|
priv struct OiOrderedOperandFact {
  node_id : Int
  results : Array[@lib.ValType]
  has_control_shape : Bool
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
  {
    node_id,
    results: @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)),
    has_control_shape: optimize_instructions_forward_selected_operand_has_control_shape(
      func, node_id,
    ),
    is_trivially_pure: optimize_instructions_is_trivially_pure_operand(
      func, node_id,
    ),
    is_effect_pure: @ir.effects_is_pure(effects.node_masks[node_id]),
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
  !self.has_control_shape && self.results.length() <= 1
}

///|
fn OiOrderedOperandFact::append_discard(
  self : OiOrderedOperandFact,
  func : @ir.HotFunc,
  body : Array[Int],
) -> Bool {
  optimize_instructions_forward_selected_operand_append_discard(
    func,
    self.node_id,
    self.results,
    body,
  )
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
  if !has_effectful_non_selected {
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
  if has_later_effectful_non_selected {
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
      if has_later_effectful_non_selected {
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
  if has_later_effectful_non_selected {
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
priv struct OiArrayDefaultValueFact {
  is_default : Bool
  preservation_plan : OiChildLocalizationPlanFact
}

///|
fn optimize_instructions_array_value_is_default_for_storage(
  func : @ir.HotFunc,
  storage : @lib.StorageType,
  value_id : Int,
) -> Bool {
  let value = @ir.hot_node_get(func, value_id)
  match storage.unpack() {
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
fn optimize_instructions_array_default_fallthrough_preserve_needed(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  value_id : Int,
  fallthrough_id : Int,
  depth? : Int = 0,
) -> Bool {
  if value_id == fallthrough_id || depth > 8 {
    return false
  }
  let value = @ir.hot_node_get(func, value_id)
  match value.op {
    @ir.HotOp::LocalTee if value.child_count == 1 => true
    @ir.HotOp::Block if value.child_count > 0 => {
      for slot = 0; slot < value.child_count - 1; slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, value_id, slot)
        if !@ir.effects_is_pure(node_masks[child_id]) {
          return true
        }
      }
      optimize_instructions_array_default_fallthrough_preserve_needed(
        func,
        node_masks,
        @ir.hot_child_get(func, value_id, value.child_count - 1),
        fallthrough_id,
        depth=depth + 1,
      )
    }
    @ir.HotOp::Loop => !@ir.effects_is_pure(node_masks[value_id])
    @ir.HotOp::If => true
    _ => !@ir.effects_is_pure(node_masks[value_id])
  }
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
    if !@ir.effects_is_pure(effects.node_masks[child_id]) {
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
  if optimize_instructions_array_default_fallthrough_preserve_needed(
      func, node_masks, value_id, fallthrough_id,
    ) {
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
  if !optimize_instructions_array_value_is_default_for_storage(
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
  if !optimize_instructions_node_is_live(func, dead, array_id) ||
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
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
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
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
            len,
          ) => len
        _ => return false
      }
      match optimize_instructions_i32_const(func, dead, repeated_value_id) {
        Some(_) => len
        None => {
          if optimize_instructions_is_trivially_pure_operand(
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
  if !optimize_instructions_node_is_live(func, dead, array_id) ||
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
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
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
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
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
    if optimize_instructions_forward_selected_operand_has_control_shape(
        func, repeated_value_id,
      ) {
      return false
    }
    if @ir.hot_type_results(func, @ir.hot_node_type(func, repeated_value_id)).length() !=
      1 {
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
  if !optimize_instructions_node_is_live(func, dead, array_id) ||
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
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
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
        Some(@lib.I32(len)) if optimize_instructions_array_new_len_is_known_non_trapping(
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
  if !optimize_instructions_node_is_live(func, dead, struct_id) ||
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
fn optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
  instr : @lib.Instruction,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) => {
      if lhs_instr != instr || rhs_instr != instr {
        return false
      }
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_left),
          optimize_instructions_local_get_id(func, dead, rhs_left),
          optimize_instructions_local_get_id(func, dead, lhs_right),
          optimize_instructions_local_get_id(func, dead, rhs_right),
        ) {
        (
          Some(lhs_left_local),
          Some(rhs_left_local),
          Some(lhs_right_local),
          Some(rhs_right_local),
        ) =>
          lhs_left_local == rhs_left_local && lhs_right_local == rhs_right_local
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_i32_add_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_add(),
  )
}

///|
fn optimize_instructions_i64_add_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_add(),
  )
}

///|
fn optimize_instructions_i32_mul_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_mul(),
  )
}

///|
fn optimize_instructions_i32_sub_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_sub(),
  )
}

///|
fn optimize_instructions_i32_bitwise_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_and(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_or(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_xor(),
  )
}

///|
fn optimize_instructions_i32_shift_rotate_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_shl(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_shr_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_shr_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_rotl(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_rotr(),
  )
}

///|
fn optimize_instructions_i64_mul_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_mul(),
  )
}

///|
fn optimize_instructions_i64_sub_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_sub(),
  )
}

///|
fn optimize_instructions_i64_bitwise_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_and(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_or(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_xor(),
  )
}

///|
fn optimize_instructions_i64_shift_rotate_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_shl(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_shr_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_shr_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_rotl(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_rotr(),
  )
}

///|
fn optimize_instructions_i32_compare_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_eq(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ne(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_lt_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_lt_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_gt_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_gt_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_le_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_le_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ge_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ge_u(),
  )
}

///|
fn optimize_instructions_i64_compare_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_eq(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ne(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_lt_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_lt_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_gt_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_gt_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_le_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_le_u(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ge_s(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ge_u(),
  )
}

///|
fn optimize_instructions_f32_binary_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_add(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_sub(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_mul(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_div(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_min(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_max(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_copysign(),
  )
}

///|
fn optimize_instructions_f64_binary_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_add(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_sub(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_mul(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_div(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_min(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_max(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_copysign(),
  )
}

///|
fn optimize_instructions_f32_compare_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_eq(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_ne(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_lt(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_gt(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_le(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_ge(),
  )
}

///|
fn optimize_instructions_f64_compare_local_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_eq(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_ne(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_lt(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_gt(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_le(),
  ) ||
  optimize_instructions_local_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_ge(),
  )
}

///|
fn optimize_instructions_i32_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
  instr : @lib.Instruction,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) => {
      if lhs_instr != instr || rhs_instr != instr {
        return false
      }
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_left),
          optimize_instructions_local_get_id(func, dead, rhs_left),
          optimize_instructions_i32_const(func, dead, lhs_right),
          optimize_instructions_i32_const(func, dead, rhs_right),
        ) {
        (Some(lhs_local), Some(rhs_local), Some(lhs_const), Some(rhs_const)) =>
          lhs_local == rhs_local && lhs_const == rhs_const
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_i64_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
  instr : @lib.Instruction,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) => {
      if lhs_instr != instr || rhs_instr != instr {
        return false
      }
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_left),
          optimize_instructions_local_get_id(func, dead, rhs_left),
          optimize_instructions_i64_const(func, dead, lhs_right),
          optimize_instructions_i64_const(func, dead, rhs_right),
        ) {
        (Some(lhs_local), Some(rhs_local), Some(lhs_const), Some(rhs_const)) =>
          lhs_local == rhs_local && lhs_const == rhs_const
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_f32_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
  instr : @lib.Instruction,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) => {
      if lhs_instr != instr || rhs_instr != instr {
        return false
      }
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_left),
          optimize_instructions_local_get_id(func, dead, rhs_left),
          optimize_instructions_f32_const(func, dead, lhs_right),
          optimize_instructions_f32_const(func, dead, rhs_right),
        ) {
        (Some(lhs_local), Some(rhs_local), Some(lhs_const), Some(rhs_const)) =>
          lhs_local == rhs_local && lhs_const == rhs_const
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_f64_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
  instr : @lib.Instruction,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 2, 2) => {
      if lhs_instr != instr || rhs_instr != instr {
        return false
      }
      let lhs_left = @ir.hot_child_get(func, lhs, 0)
      let lhs_right = @ir.hot_child_get(func, lhs, 1)
      let rhs_left = @ir.hot_child_get(func, rhs, 0)
      let rhs_right = @ir.hot_child_get(func, rhs, 1)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_left),
          optimize_instructions_local_get_id(func, dead, rhs_left),
          optimize_instructions_f64_const(func, dead, lhs_right),
          optimize_instructions_f64_const(func, dead, rhs_right),
        ) {
        (Some(lhs_local), Some(rhs_local), Some(lhs_const), Some(rhs_const)) =>
          lhs_local == rhs_local && lhs_const == rhs_const
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
  instr : @lib.Instruction,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(lhs_instr), Some(rhs_instr), 1, 1) => {
      if lhs_instr != instr || rhs_instr != instr {
        return false
      }
      let lhs_child = @ir.hot_child_get(func, lhs, 0)
      let rhs_child = @ir.hot_child_get(func, rhs, 0)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_child),
          optimize_instructions_local_get_id(func, dead, rhs_child),
        ) {
        (Some(lhs_local), Some(rhs_local)) => lhs_local == rhs_local
        _ => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_i32_unary_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_eqz(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_clz(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ctz(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_popcnt(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_extend8s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_extend16s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_trunc_sat_f32s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_trunc_sat_f32u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_trunc_sat_f64s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_trunc_sat_f64u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_reinterpret_f32(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_wrap_i64(),
  )
}

///|
fn optimize_instructions_i64_unary_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_eqz(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_clz(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ctz(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_popcnt(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_extend8s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_extend16s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_extend32s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_extend_i32s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_extend_i32u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_trunc_sat_f32s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_trunc_sat_f32u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_trunc_sat_f64s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_trunc_sat_f64u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_reinterpret_f64(),
  )
}

///|
fn optimize_instructions_f32_unary_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_abs(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_neg(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_ceil(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_floor(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_trunc(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_nearest(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_sqrt(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_convert_i32s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_convert_i32u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_convert_i64s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_convert_i64u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_demote_f64(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_reinterpret_i32(),
  )
}

///|
fn optimize_instructions_f64_unary_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_abs(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_neg(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_ceil(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_floor(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_trunc(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_nearest(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_sqrt(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_convert_i32s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_convert_i32u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_convert_i64s(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_convert_i64u(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_promote_f32(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_reinterpret_i64(),
  )
}

///|
fn optimize_instructions_f32_binary_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_add(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_sub(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_mul(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_div(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_min(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_max(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_copysign(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_eq(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_ne(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_lt(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_gt(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_le(),
  ) ||
  optimize_instructions_f32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32_ge(),
  )
}

///|
fn optimize_instructions_f64_binary_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_add(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_sub(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_mul(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_div(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_min(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_max(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_copysign(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_eq(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_ne(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_lt(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_gt(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_le(),
  ) ||
  optimize_instructions_f64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64_ge(),
  )
}

///|
fn optimize_instructions_v128_consts_are_identical_pure(
  func : @ir.HotFunc,
  lhs : Int,
  rhs : Int,
) -> Bool {
  match
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
}

///|
fn optimize_instructions_v128_splat_local_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i8x16_splat(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i16x8_splat(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32x4_splat(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64x2_splat(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f32x4_splat(),
  ) ||
  optimize_instructions_unary_local_payloads_are_identical_pure_with_instr(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::f64x2_splat(),
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
  {
    matching_ref_i31_payload: optimize_instructions_ref_i31_payloads_are_identical_nontrapping_reorderable(
      func, dead, if_true, if_false,
    ),
    matching_i32_local_local_scalar: optimize_instructions_i32_add_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i32_sub_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i32_mul_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i32_bitwise_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i32_shift_rotate_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i32_compare_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_i64_local_local_scalar: optimize_instructions_i64_add_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i64_sub_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i64_mul_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i64_bitwise_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i64_shift_rotate_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_i64_compare_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_i32_local_const_scalar: optimize_instructions_i32_nontrapping_local_const_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_i64_local_const_scalar: optimize_instructions_i64_nontrapping_local_const_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_i32_unary_local_scalar: optimize_instructions_i32_unary_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_i64_unary_local_scalar: optimize_instructions_i64_unary_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_f32_scalar: optimize_instructions_f32_compare_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_f32_unary_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_f32_binary_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_f32_binary_local_const_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
    matching_f64_scalar: optimize_instructions_f64_compare_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_f64_unary_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_f64_binary_local_local_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ) ||
    optimize_instructions_f64_binary_local_const_payloads_are_identical_pure(
      func, dead, if_true, if_false,
    ),
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
fn optimize_instructions_reference_leaves_equal(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match (@ir.hot_node_get(func, lhs_id), @ir.hot_node_get(func, rhs_id)) {
    (
      { op: @ir.HotOp::RefNull, ty: lhs_ty, .. },
      { op: @ir.HotOp::RefNull, ty: rhs_ty, .. },
    ) => return lhs_ty == rhs_ty
    (
      { op: @ir.HotOp::RefFunc, ty: lhs_ty, imm0: lhs_func, .. },
      { op: @ir.HotOp::RefFunc, ty: rhs_ty, imm0: rhs_func, .. },
    ) => return lhs_ty == rhs_ty && lhs_func == rhs_func
    _ => ()
  }
  match
    (
      @ir.hot_node_exact_instr(func, lhs_id),
      @ir.hot_node_exact_instr(func, rhs_id),
    ) {
    (Some(@lib.Instruction::RefNull(lhs)), Some(@lib.Instruction::RefNull(rhs))) =>
      lhs == rhs
    (Some(@lib.Instruction::RefFunc(lhs)), Some(@lib.Instruction::RefFunc(rhs))) =>
      lhs == rhs
    _ => false
  }
}

///|
fn optimize_instructions_local_const_select_scalar_tree_is_nontrapping_reorderable(
  func : @ir.HotFunc,
  node_id : Int,
  depth? : Int = 0,
) -> Bool {
  // Same-value select-arm folding across an effectful condition moves the kept
  // value after that condition. This fact is the source-backed, represented
  // `ref.i31` payload subset that cannot trap and cannot observe calls, globals,
  // memory, or tables: local/const leaves plus branchless select shells whose
  // arms and condition recursively have the same property.
  if depth > 16 {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet | @ir.HotOp::Const => true
    @ir.HotOp::Select => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !optimize_instructions_local_const_select_scalar_tree_is_nontrapping_reorderable(
            func,
            @ir.hot_child_get(func, node_id, slot),
            depth=depth + 1,
          ) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn optimize_instructions_ref_i31_scalar_trees_equal(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  // Binaryen v130 `ExpressionAnalyzer::equal` compares `ref.i31` shells by
  // recursively comparing their i32 payloads. Keep this as a fact-owned
  // represented reference-tree proof instead of growing the legacy ref.i31
  // payload opcode whitelist.
  let lhs = @ir.hot_node_get(func, lhs_id)
  let rhs = @ir.hot_node_get(func, rhs_id)
  if lhs.ty != rhs.ty || lhs.child_count != 1 || rhs.child_count != 1 {
    return false
  }
  match
    (
      @ir.hot_node_exact_instr(func, lhs_id),
      @ir.hot_node_exact_instr(func, rhs_id),
    ) {
    (Some(@lib.Instruction::RefI31), Some(@lib.Instruction::RefI31)) =>
      optimize_instructions_pure_scalar_tree_equal(
        func,
        @ir.hot_child_get(func, lhs_id, 0),
        @ir.hot_child_get(func, rhs_id, 0),
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_i31_nontrapping_local_scalar_trees_equal(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  if !optimize_instructions_ref_i31_scalar_trees_equal(func, lhs_id, rhs_id) {
    return false
  }
  let lhs_payload = @ir.hot_child_get(func, lhs_id, 0)
  let rhs_payload = @ir.hot_child_get(func, rhs_id, 0)
  optimize_instructions_local_const_select_scalar_tree_is_nontrapping_reorderable(
    func, lhs_payload,
  ) &&
  optimize_instructions_local_const_select_scalar_tree_is_nontrapping_reorderable(
    func, rhs_payload,
  )
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
  let scalar_tree = optimize_instructions_pure_scalar_tree_equal(
    func, if_true, if_false,
  )
  let state_read = optimize_instructions_stable_state_reads_equal(left, right)
  let state_scalar_tree = optimize_instructions_stable_state_scalar_tree_equal(
    func, if_true, if_false,
  )
  let reference_leaf = optimize_instructions_reference_leaves_equal(
    func, if_true, if_false,
  )
  let ref_i31_scalar_tree = optimize_instructions_ref_i31_scalar_trees_equal(
    func, if_true, if_false,
  )
  let ref_i31_nontrapping_local_scalar_tree = optimize_instructions_ref_i31_nontrapping_local_scalar_trees_equal(
    func, if_true, if_false,
  )
  let v128_const_leaf = optimize_instructions_v128_consts_are_identical_pure(
    func, if_true, if_false,
  )
  let v128_local_splat = optimize_instructions_v128_splat_local_payloads_are_identical_pure(
    func, dead, if_true, if_false,
  )
  let nontrapping_reorderable_scalar_tree = OiNontrappingReorderableExpressionEqualityFact::from_select_arms(
    func, dead, if_true, if_false,
  ).proves_equal()
  let effect_safe = if state_read || state_scalar_tree {
    true
  } else {
    optimize_instructions_is_side_effect_free_expr(func, dead, if_true) &&
    optimize_instructions_is_side_effect_free_expr(func, dead, if_false)
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
    matching_v128_const_leaf: v128_const_leaf,
    matching_v128_local_splat: v128_local_splat,
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
fn optimize_instructions_i32_nontrapping_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_add(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_sub(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_mul(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_and(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_or(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_xor(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_shl(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_shr_u(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_shr_s(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_rotl(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_rotr(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_eq(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ne(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_lt_s(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_lt_u(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_gt_s(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_gt_u(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_le_s(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_le_u(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ge_s(),
  ) ||
  optimize_instructions_i32_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i32_ge_u(),
  )
}

///|
fn optimize_instructions_i64_nontrapping_local_const_payloads_are_identical_pure(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_add(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_sub(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_mul(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_and(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_or(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_xor(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_shl(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_shr_u(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_shr_s(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_rotl(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_rotr(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_eq(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ne(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_lt_s(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_lt_u(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_gt_s(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_gt_u(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_le_s(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_le_u(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ge_s(),
  ) ||
  optimize_instructions_i64_local_const_payloads_are_identical_pure(
    func,
    dead,
    lhs,
    rhs,
    @lib.Instruction::i64_ge_u(),
  )
}

///|
fn optimize_instructions_ref_i31_payloads_are_identical_nontrapping_reorderable(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  lhs : Int,
  rhs : Int,
) -> Bool {
  match
    (
      @ir.hot_node_exact_instr(func, lhs),
      @ir.hot_node_exact_instr(func, rhs),
      @ir.hot_node_get(func, lhs).child_count,
      @ir.hot_node_get(func, rhs).child_count,
    ) {
    (Some(@lib.Instruction::RefI31), Some(@lib.Instruction::RefI31), 1, 1) => {
      let lhs_payload = @ir.hot_child_get(func, lhs, 0)
      let rhs_payload = @ir.hot_child_get(func, rhs, 0)
      match
        (
          optimize_instructions_local_get_id(func, dead, lhs_payload),
          optimize_instructions_local_get_id(func, dead, rhs_payload),
        ) {
        (Some(lhs_local), Some(rhs_local)) => return lhs_local == rhs_local
        _ => ()
      }
      match
        (
          optimize_instructions_i32_const(func, dead, lhs_payload),
          optimize_instructions_i32_const(func, dead, rhs_payload),
        ) {
        (Some(lhs_const), Some(rhs_const)) => return lhs_const == rhs_const
        _ => ()
      }
      optimize_instructions_i32_add_local_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_sub_local_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_mul_local_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_bitwise_local_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_shift_rotate_local_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_compare_local_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_nontrapping_local_const_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      ) ||
      optimize_instructions_i32_unary_local_payloads_are_identical_pure(
        func, dead, lhs_payload, rhs_payload,
      )
    }
    _ => false
  }
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
      if !optimize_instructions_node_is_live(func, dead, inner_condition) {
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
      if !optimize_instructions_node_is_live(func, dead, inner_condition) {
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
                  if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
                    !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
              if !optimize_instructions_node_is_live(
                  func, dead, inner_condition,
                ) {
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
              if !optimize_instructions_node_is_live(
                  func, dead, inner_condition,
                ) {
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
              if !optimize_instructions_node_is_live(func, dead, condition) {
                return false
              }
              optimize_instructions_replace_with_node_id(
                ctx, func, node_id, condition,
              )
              return true
            }
            (Some(@lib.I32(0)), Some(@lib.I32(1))) => {
              if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
                !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
              if !optimize_instructions_node_is_live(func, dead, condition) {
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
              if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
                !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
    if optimize_instructions_is_side_effect_free_expr(func, dead, condition) {
      optimize_instructions_replace_with_node_id(ctx, func, node_id, if_true)
      return true
    }
    if (
        (
          optimize_instructions_is_shared_cross_safe_leaf(func, dead, if_true) &&
          optimize_instructions_is_shared_cross_safe_leaf(func, dead, if_false)
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
  if !optimize_instructions_is_side_effect_free_expr(func, dead, dead_arm) {
    return false
  }
  if !optimize_instructions_is_side_effect_free_expr(func, dead, chosen) {
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
  if !optimize_instructions_node_is_live(func, dead, lhs_id) ||
    !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
  if !optimize_instructions_node_is_live(func, dead, lhs_operand_id) ||
    !optimize_instructions_node_is_live(func, dead, rhs_operand_id) {
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
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, operand_id) {
    return false
  }
  let operand = func.nodes[operand_id]
  match (instr, operand.op, @ir.hot_node_exact_instr(func, operand_id)) {
    (@lib.Instruction::I32Eqz, @ir.HotOp::Unary, Some(@lib.Instruction::I32Eqz)) => {
      let inner_operand_id = @ir.hot_child_get(func, operand_id, 0)
      if !optimize_instructions_node_is_live(func, dead, inner_operand_id) {
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
      if !optimize_instructions_node_is_live(func, dead, inner_operand_id) {
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
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
    optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id)
  } else if zero_on_rhs && !zero_on_lhs {
    optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id)
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
    optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id)
  } else if zero_on_rhs && !zero_on_lhs {
    optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id)
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
    if optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id) {
      None
    } else {
      Some(rhs_id)
    }
  } else if neg_one_on_rhs && !neg_one_on_lhs {
    if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
    if optimize_instructions_is_side_effect_free_expr(func, dead, rhs_id) {
      None
    } else {
      Some(rhs_id)
    }
  } else if neg_one_on_rhs && !neg_one_on_lhs {
    if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
        optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
fn optimize_instructions_try_fold_convert(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
  instr : @lib.Instruction,
  operand_id : Int,
) -> Bool {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
/// Effect bits a value-expression subtree may carry and still be a candidate
/// for operand reordering: pure reads of locals, globals, memory, and tables.
/// Any write, trap, call, throw, or control-flow bit is order-sensitive.
fn optimize_instructions_reorder_read_effects() -> UInt {
  @ir.EFFECT_MASK_LOCAL_STATE |
  @ir.EFFECT_MASK_GLOBAL_STATE |
  @ir.EFFECT_MASK_MEMORY_READ |
  @ir.EFFECT_MASK_TABLE_READ
}

///|
/// `(writes_local, writes_global)` for a value-expression subtree: whether it
/// contains a `local.set`/`local.tee` or a `global.set`. The coarse
/// `EFFECT_MASK_LOCAL_STATE`/`EFFECT_MASK_GLOBAL_STATE` bits conflate reads and
/// writes, so region-conflict detection needs this precise walk. It only recurses
/// value children; callers must reject control-flow operands first (see
/// `optimize_instructions_subtrees_can_swap`), whose region bodies are not
/// reflected in the aggregated node masks.
fn optimize_instructions_subtree_state_writes(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Bool, Bool) {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return (false, false)
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut writes_local = false
  let mut writes_global = false
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => writes_local = true
    @ir.HotOp::GlobalSet => writes_global = true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let (child_local, child_global) = optimize_instructions_subtree_state_writes(
      func,
      @ir.hot_child_get(func, node_id, slot),
    )
    writes_local = writes_local || child_local
    writes_global = writes_global || child_global
  }
  (writes_local, writes_global)
}

///|
/// Regions a subtree writes, expressed in the read-effect namespace so the
/// result can be intersected with another operand's read mask. Memory and table
/// writes plus opaque `call` effects are precise in the node mask; local and
/// global writes use the precise `optimize_instructions_subtree_state_writes`
/// walk. A `call` may write memory, globals, and tables but never the caller's
/// locals.
fn optimize_instructions_subtree_write_mask(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  node_id : Int,
) -> UInt {
  let mask = node_masks[node_id]
  let mut writes = 0U
  if (mask & (@ir.EFFECT_MASK_MEMORY_WRITE | @ir.EFFECT_MASK_CALL)) != 0U {
    writes = writes | @ir.EFFECT_MASK_MEMORY_READ
  }
  if (mask & (@ir.EFFECT_MASK_TABLE_WRITE | @ir.EFFECT_MASK_CALL)) != 0U {
    writes = writes | @ir.EFFECT_MASK_TABLE_READ
  }
  if (mask & @ir.EFFECT_MASK_CALL) != 0U {
    writes = writes | @ir.EFFECT_MASK_GLOBAL_STATE
  }
  let (writes_local, writes_global) = optimize_instructions_subtree_state_writes(
    func, node_id,
  )
  if writes_local {
    writes = writes | @ir.EFFECT_MASK_LOCAL_STATE
  }
  if writes_global {
    writes = writes | @ir.EFFECT_MASK_GLOBAL_STATE
  }
  writes
}

///|
/// Whether two operand subtrees may be swapped (as in the leading
/// `(0 - x) + y => y - x` rewrite, which reorders `x` and `y`) without changing
/// observable behavior. Mirrors Binaryen's `optimize-instructions` reorder rule:
///
/// - there is no read-after-write / write-after-read / write-after-write
///   conflict on locals, globals, memory, or tables (read x read is fine, which
///   is why `local.get x local.get`, `load x load`, and a `local.get` across a
///   `call` all reorder);
/// - there is no may-trap-or-throw vs side-effect hazard (reordering a trapping
///   op past a side effect would change whether the effect is observed), which
///   is why `(0 - load) + local.tee` and `(0 - memory.grow) + load` stay put;
/// - operands carrying control flow never swap, because their region bodies are
///   not reflected in the aggregated node masks.
fn optimize_instructions_subtrees_can_swap(
  func : @ir.HotFunc,
  node_masks : Array[UInt],
  a_id : Int,
  b_id : Int,
) -> Bool {
  if a_id < 0 ||
    a_id >= node_masks.length() ||
    b_id < 0 ||
    b_id >= node_masks.length() {
    return false
  }
  let a_mask = node_masks[a_id]
  let b_mask = node_masks[b_id]
  // Control-flow operands carry effects inside regions that the aggregated
  // node masks do not reflect; never reorder across them.
  if (a_mask & @ir.EFFECT_MASK_CONTROL) != 0U ||
    (b_mask & @ir.EFFECT_MASK_CONTROL) != 0U {
    return false
  }
  let read_bits = optimize_instructions_reorder_read_effects()
  let a_reads = a_mask & read_bits
  let b_reads = b_mask & read_bits
  let a_writes = optimize_instructions_subtree_write_mask(
    func, node_masks, a_id,
  )
  let b_writes = optimize_instructions_subtree_write_mask(
    func, node_masks, b_id,
  )
  // RAW / WAR / WAW on any shared region.
  let region_conflict = ((a_reads | a_writes) & b_writes) != 0U ||
    ((b_reads | b_writes) & a_writes) != 0U
  if region_conflict {
    return false
  }
  // A may-trap-or-throw operand reordered past a side effect would change
  // whether that effect is observed before the trap/throw.
  let a_disrupts = (a_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)) !=
    0U
  let b_disrupts = (b_mask & (@ir.EFFECT_MASK_TRAP | @ir.EFFECT_MASK_THROW)) !=
    0U
  let a_side_effect = a_writes != 0U || (a_mask & @ir.EFFECT_MASK_THROW) != 0U
  let b_side_effect = b_writes != 0U || (b_mask & @ir.EFFECT_MASK_THROW) != 0U
  if (a_disrupts && b_side_effect) || (b_disrupts && a_side_effect) {
    return false
  }
  true
}

///|
fn optimize_instructions_can_swap_leading_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  a_id : Int,
  b_id : Int,
) -> Bool {
  let effects = pass_require_effects(ctx, func)
  optimize_instructions_subtrees_can_swap(func, effects.node_masks, a_id, b_id)
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
      if !optimize_instructions_i32_mask_is_low_ones(mask) {
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
      if !optimize_instructions_i64_mask_is_low_ones(mask) {
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
              optimize_instructions_can_swap_leading_operands(
                ctx, func, rhs_id, sub_rhs_id,
              ) {
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
              optimize_instructions_can_swap_leading_operands(
                ctx, func, rhs_id, sub_rhs_id,
              ) {
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
  if !optimize_instructions_node_is_live(func, dead, lhs_id) {
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

  if !optimize_instructions_node_is_live(func, dead, rhs_id) {
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
  if !optimize_instructions_node_is_live(func, dead, lhs_id) {
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
  if !optimize_instructions_is_trivially_pure_value(func, dead, lhs_id) {
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
fn optimize_instructions_is_remainder_instr(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if !optimize_instructions_node_is_live(func, dead, node_id) {
    return false
  }
  let exact_id = match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, node_id) == 1 =>
      @ir.hot_child_get(func, node_id, 0)
    _ => node_id
  }
  match @ir.hot_node_exact_instr(func, exact_id) {
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
fn optimize_instructions_replace_with_ref_is_null(
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
fn optimize_instructions_replace_with_ref_is_non_null_test(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  operand_id : Int,
) -> Unit {
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
fn optimize_instructions_ref_is_known_non_null(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
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

///|
fn optimize_instructions_ref_is_null_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::RefNull => true
    _ =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefNull(_)) => true
        _ => false
      }
  }
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
  let source = ref_type.get_heap_type()
  if source == target ||
    (
      source == @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
      optimize_instructions_ref_i31_matches_target(target)
    ) ||
    optimize_instructions_abs_struct_array_matches_target(source, target) {
    return true
  }
  match ctx.module_ctx {
    Some(module_ctx) =>
      optimize_instructions_heap_matches_target(module_ctx, source, target, 512)
    None => false
  }
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
fn optimize_instructions_ref_is_known_non_null_i31(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable() &&
          ref_type.get_heap_type() ==
          @lib.HeapType::abs(@lib.AbsHeapType::i31())
        _ => false
      }
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) => true
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_cannot_be_i31(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          optimize_instructions_ref_i31_cannot_match_target(
            ref_type.get_heap_type(),
          )
        _ => false
      }
    _ => false
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
fn optimize_instructions_concrete_source_has_no_target_overlap(
  module_ctx : @ir.HotModuleContext?,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  let ctx = match module_ctx {
    Some(ctx) => ctx
    None => return false
  }
  match source {
    @lib.HeapType::HeapType(_) => ()
    _ => return false
  }
  if optimize_instructions_heap_matches_target(ctx, source, target, 512) {
    return false
  }
  let subtype_count = @ir.hot_module_subtype_count(ctx)
  for i = 0; i < subtype_count; i = i + 1 {
    let heap = @lib.HeapType::new(@lib.TypeIdx::new(i.reinterpret_as_uint()))
    if optimize_instructions_heap_matches_target(ctx, heap, source, 512) &&
      optimize_instructions_heap_matches_target(ctx, heap, target, 512) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_ref_local_heap_type(
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.RefType? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) => Some(ref_type)
        _ => None
      }
    _ => None
  }
}

///|
fn optimize_instructions_ref_local_heaps_are_impossible_equal(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_ref_local_heap_type(func, lhs_id),
      optimize_instructions_ref_local_heap_type(func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) =>
      (lhs.is_non_nullable() || rhs.is_non_nullable()) &&
      optimize_instructions_abs_struct_array_disjoint(
        lhs.get_heap_type(),
        rhs.get_heap_type(),
      )
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_null_or_known_miss_for_non_null_target(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          (
            ref_type.get_heap_type() ==
            @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
            optimize_instructions_ref_i31_cannot_match_target(target)
          ) ||
          optimize_instructions_abs_struct_array_disjoint(
            ref_type.get_heap_type(),
            target,
          ) ||
          optimize_instructions_concrete_source_has_no_target_overlap(
            ctx.module_ctx,
            ref_type.get_heap_type(),
            target,
          )
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_known_miss_for_target(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable() &&
          (
            (
              ref_type.get_heap_type() ==
              @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
              optimize_instructions_ref_i31_cannot_match_target(target)
            ) ||
            optimize_instructions_abs_struct_array_disjoint(
              ref_type.get_heap_type(),
              target,
            ) ||
            optimize_instructions_concrete_source_has_no_target_overlap(
              ctx.module_ctx,
              ref_type.get_heap_type(),
              target,
            )
          )
        _ => false
      }
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) =>
          optimize_instructions_ref_i31_cannot_match_target(target)
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_known_match_for_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_non_nullable() &&
          (
            ref_type.get_heap_type() == target ||
            (
              ref_type.get_heap_type() ==
              @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
              optimize_instructions_ref_i31_matches_target(target)
            ) ||
            optimize_instructions_abs_struct_array_matches_target(
              ref_type.get_heap_type(),
              target,
            )
          )
        _ => false
      }
    @ir.HotOp::RefFunc => optimize_instructions_ref_func_matches_target(target)
    @ir.HotOp::Heap =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefI31) =>
          optimize_instructions_ref_i31_matches_target(target)
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_is_known_match_for_nullable_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_local_type(func, node.imm0) {
        Some(@lib.ValType::RefTypeValType(ref_type)) =>
          ref_type.is_nullable() &&
          (
            ref_type.get_heap_type() == target ||
            (
              ref_type.get_heap_type() ==
              @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
              optimize_instructions_ref_i31_matches_target(target)
            ) ||
            optimize_instructions_abs_struct_array_matches_target(
              ref_type.get_heap_type(),
              target,
            )
          )
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_is_nullable_exact_heap(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] =>
      ref_type.is_nullable() && ref_type.get_heap_type() == target
    _ => false
  }
}

///|
fn optimize_instructions_heap_is_final(
  module_ctx : @ir.HotModuleContext,
  heap : @lib.HeapType,
) -> Bool {
  match heap {
    @lib.HeapType::HeapType(type_idx) =>
      match @ir.hot_module_resolve_subtype(module_ctx, type_idx) {
        Some(@lib.CompTypeSubType(_, _)) => true
        Some(@lib.SubType(true, _, _, _)) => true
        _ => false
      }
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_misses_exact_target(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] =>
      ref_type.is_exact() &&
      ref_type.get_heap_type() != target &&
      (ref_type.is_non_nullable() || !target_nullable)
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_misses_exact_target_by_strict_subtype(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => {
      let source = ref_type.get_heap_type()
      match (source, target) {
        (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => ()
        _ => return false
      }
      source != target &&
      (ref_type.is_non_nullable() || !target_nullable) &&
      optimize_instructions_heap_matches_target(module_ctx, source, target, 512)
    }
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_matches_nullable_exact_target_only_as_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
  target_nullable : Bool,
) -> Bool {
  if !target_nullable {
    return false
  }
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => {
      if ref_type.is_non_nullable() {
        return false
      }
      let source = ref_type.get_heap_type()
      match (source, target) {
        (@lib.HeapType::HeapType(_), @lib.HeapType::HeapType(_)) => ()
        _ => return false
      }
      source != target &&
      (
        ref_type.is_exact() ||
        optimize_instructions_heap_matches_target(
          module_ctx, source, target, 512,
        )
      )
    }
    _ => false
  }
}

///|
fn optimize_instructions_ref_operand_has_exact_heap(
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] =>
      ref_type.is_exact() && ref_type.get_heap_type() == target
    _ => false
  }
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
fn optimize_instructions_try_fold_ref_is_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  match @ir.hot_node_get(func, operand_id).op {
    @ir.HotOp::RefNull => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        @lib.I32(1),
      )
      true
    }
    _ if OiRefFact::from_node(func, operand_id).is_known_non_null() => {
      if optimize_instructions_node_effects_are_pure(ctx, func, operand_id) {
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
          operand_id,
          @lib.I32(0),
        )
      }
      true
    }
    _ => false
  }
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
fn optimize_instructions_descriptor_skip_may_drop_exactness_for_tnh_escaping_ref_get_desc(
  func : @ir.HotFunc,
  descriptor_id : Int,
) -> Bool {
  match OiRefGetDescFact::from_node(func, descriptor_id) {
    Some(_) =>
      optimize_instructions_descriptor_expr_has_escaping_branch_control(
        func, descriptor_id,
      )
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
fn optimize_instructions_descriptor_nullable_if_child_can_move_null_check(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if node.child_count != 3 {
    return false
  }
  if !optimize_instructions_is_side_effect_free_expr(
      func,
      dead,
      @ir.hot_child_get(func, node_id, 0),
    ) {
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
  optimize_instructions_is_side_effect_free_expr(
    func,
    dead,
    @ir.hot_region_get(func, then_region, 0),
  ) &&
  optimize_instructions_is_side_effect_free_expr(
    func,
    dead,
    @ir.hot_region_get(func, else_region, 0),
  )
}

///|
fn optimize_instructions_descriptor_nullable_if_child_can_move_null_check_with_effects(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if node.child_count != 3 {
    return false
  }
  if optimize_instructions_descriptor_expr_has_escaping_branch_control(
      func,
      @ir.hot_child_get(func, node_id, 0),
    ) {
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
  !optimize_instructions_descriptor_region_has_escaping_branch_control_from(
    func, node_id, then_region,
  ) &&
  !optimize_instructions_descriptor_region_has_escaping_branch_control_from(
    func, node_id, else_region,
  )
}

///|
fn optimize_instructions_descriptor_region_has_branch_control(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for slot = 0
      slot < @ir.hot_region_root_count(func, region_ref)
      slot = slot + 1 {
    if optimize_instructions_descriptor_expr_has_branch_control(
        func,
        @ir.hot_region_get(func, region_ref, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_descriptor_expr_has_branch_control(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => return true
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      if optimize_instructions_descriptor_region_has_branch_control(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
    @ir.HotOp::If => {
      if optimize_instructions_descriptor_expr_has_branch_control(
          func,
          @ir.hot_child_get(func, node_id, 0),
        ) ||
        optimize_instructions_descriptor_region_has_branch_control(
          func,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          if optimize_instructions_descriptor_region_has_branch_control(
              func, region_ref,
            ) {
            return true
          }
        None => ()
      }
    }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if optimize_instructions_descriptor_expr_has_branch_control(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_descriptor_region_contains_node(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_id : Int,
) -> Bool {
  for slot = 0
      slot < @ir.hot_region_root_count(func, region_ref)
      slot = slot + 1 {
    if optimize_instructions_descriptor_node_contains(
        func,
        @ir.hot_region_get(func, region_ref, slot),
        target_id,
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_descriptor_node_contains(
  func : @ir.HotFunc,
  root_id : Int,
  target_id : Int,
) -> Bool {
  if root_id == target_id {
    return true
  }
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return false
  }
  let node = @ir.hot_node_get(func, root_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if optimize_instructions_descriptor_node_contains(
        func,
        @ir.hot_child_get(func, root_id, slot),
        target_id,
      ) {
      return true
    }
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      optimize_instructions_descriptor_region_contains_node(
        func,
        @ir.hot_region_body_ref(func, root_id),
        target_id,
      )
    @ir.HotOp::If => {
      if optimize_instructions_descriptor_region_contains_node(
          func,
          @ir.hot_region_then_ref(func, root_id),
          target_id,
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, root_id) {
        Some(region_ref) =>
          optimize_instructions_descriptor_region_contains_node(
            func, region_ref, target_id,
          )
        None => false
      }
    }
    _ => false
  }
}

///|
fn optimize_instructions_descriptor_label_is_internal_to_expr(
  func : @ir.HotFunc,
  root_id : Int,
  label_id : Int,
) -> Bool {
  if label_id < 0 || label_id >= func.labels.length() {
    return false
  }
  optimize_instructions_descriptor_node_contains(
    func,
    root_id,
    @ir.hot_label_owner(func, label_id),
  )
}

///|
fn optimize_instructions_descriptor_region_has_escaping_branch_control_from(
  func : @ir.HotFunc,
  owner_id : Int,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for slot = 0
      slot < @ir.hot_region_root_count(func, region_ref)
      slot = slot + 1 {
    if optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
        func,
        owner_id,
        @ir.hot_region_get(func, region_ref, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_descriptor_expr_has_escaping_branch_control(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
    func, node_id, node_id,
  )
}

///|
fn optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
  func : @ir.HotFunc,
  owner_id : Int,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf =>
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          node.imm0,
        ) {
        return true
      }
    @ir.HotOp::BrTable => {
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ) {
        return true
      }
      for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
        if !optimize_instructions_descriptor_label_is_internal_to_expr(
            func, owner_id, label_id,
          ) {
          return true
        }
      }
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          node.imm0,
        ) {
        return true
      }
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for slot = 0
          slot < @ir.hot_region_root_count(func, body)
          slot = slot + 1 {
        if optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
            func,
            owner_id,
            @ir.hot_region_get(func, body, slot),
          ) {
          return true
        }
      }
    }
    @ir.HotOp::If => {
      if optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
          func,
          owner_id,
          @ir.hot_child_get(func, node_id, 0),
        ) {
        return true
      }
      let then_region = @ir.hot_region_then_ref(func, node_id)
      for slot = 0
          slot < @ir.hot_region_root_count(func, then_region)
          slot = slot + 1 {
        if optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
            func,
            owner_id,
            @ir.hot_region_get(func, then_region, slot),
          ) {
          return true
        }
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          for slot = 0
              slot < @ir.hot_region_root_count(func, else_region)
              slot = slot + 1 {
            if optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
                func,
                owner_id,
                @ir.hot_region_get(func, else_region, slot),
              ) {
              return true
            }
          }
        None => ()
      }
    }
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if optimize_instructions_descriptor_expr_has_escaping_branch_control_from(
        func,
        owner_id,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
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
fn optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.ValType::RefTypeValType(ref_type)] => ref_type.is_nullable()
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_node_has_no_results(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)).length() == 0
}

///|
fn optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
  func : @ir.HotFunc,
  owner_id : Int,
  node_id : Int,
) -> Bool {
  if @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)).length() > 1 {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf =>
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          node.imm0,
        ) {
        return true
      }
    @ir.HotOp::BrTable => {
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ) {
        return true
      }
      for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
        if !optimize_instructions_descriptor_label_is_internal_to_expr(
            func, owner_id, label_id,
          ) {
          return true
        }
      }
    }
    @ir.HotOp::BrOnNonNull =>
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          node.imm0,
        ) {
        return true
      }
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
    | @ir.HotOp::CatchAll => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func,
        owner_id,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_standalone_ref_get_desc_is_internal_br_on_non_null_root(
  func : @ir.HotFunc,
  block_id : Int,
  root_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::BrOnNonNull =>
      optimize_instructions_descriptor_label_is_internal_to_expr(
        func,
        block_id,
        @ir.hot_node_get(func, root_id).imm0,
      )
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_is_escaping_br_if_root(
  func : @ir.HotFunc,
  block_id : Int,
  root_id : Int,
) -> Bool {
  let root = @ir.hot_node_get(func, root_id)
  match root.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if optimize_instructions_descriptor_label_is_internal_to_expr(
      func,
      block_id,
      root.imm0,
    ) ||
    !optimize_instructions_standalone_ref_get_desc_node_has_no_results(
      func, root_id,
    ) {
    return false
  }
  for slot = 0; slot < root.child_count; slot = slot + 1 {
    if optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func,
        block_id,
        @ir.hot_child_get(func, root_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_standalone_ref_get_desc_is_internal_br_on_cast_root(
  func : @ir.HotFunc,
  block_id : Int,
  root_id : Int,
) -> Bool {
  let root = @ir.hot_node_get(func, root_id)
  match root.op {
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail => ()
    _ => return false
  }
  if !optimize_instructions_descriptor_label_is_internal_to_expr(
      func,
      block_id,
      root.imm0,
    ) ||
    @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  let (source_nullable, target_nullable, source_heap, target_heap) = match
    @ir.hot_node_exact_instr(func, root_id) {
    Some(
      @lib.Instruction::BrOnCast(
        _,
        @lib.CastOp(src_null, dst_null),
        src_heap,
        dst_heap
      )
    ) => (src_null, dst_null, src_heap, dst_heap)
    Some(
      @lib.Instruction::BrOnCastFail(
        _,
        @lib.CastOp(src_null, dst_null),
        src_heap,
        dst_heap
      )
    ) => (src_null, dst_null, src_heap, dst_heap)
    _ => return false
  }
  if !source_nullable || target_nullable || source_heap != target_heap {
    return false
  }
  let nullable_ref = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, nullable_ref).op {
    @ir.HotOp::LocalGet =>
      match @ir.hot_type_results(func, @ir.hot_node_type(func, nullable_ref)) {
        [@lib.ValType::RefTypeValType(ref_type)] =>
          ref_type.is_nullable() && ref_type.get_heap_type() == source_heap
        _ => false
      }
    _ => false
  }
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
fn optimize_instructions_standalone_ref_get_desc_is_br_on_null_local_root(
  func : @ir.HotFunc,
  block_id : Int,
  root_id : Int,
) -> Bool {
  let root = @ir.hot_node_get(func, root_id)
  match root.op {
    @ir.HotOp::BrOnNull => ()
    _ => return false
  }
  if !optimize_instructions_standalone_ref_get_desc_label_owner_is(
      func,
      root.imm0,
      block_id,
    ) ||
    @ir.hot_child_count(func, root_id) != 1 {
    return false
  }
  let nullable_ref = @ir.hot_child_get(func, root_id, 0)
  match @ir.hot_node_get(func, nullable_ref).op {
    @ir.HotOp::LocalGet =>
      optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
        func, nullable_ref,
      )
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_is_internal_br_on_null_trampoline_root(
  func : @ir.HotFunc,
  block_id : Int,
  root_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if !optimize_instructions_standalone_ref_get_desc_node_has_no_results(
      func, root_id,
    ) {
    return false
  }
  let inner_label = @ir.hot_control_node_label(func, root_id)
  if !optimize_instructions_standalone_ref_get_desc_label_owner_is(
      func, inner_label, root_id,
    ) ||
    @ir.hot_label_branch_arity(func, inner_label) != 0 {
    return false
  }
  let body = @ir.hot_region_body_ref(func, root_id)
  let root_count = @ir.hot_region_root_count(func, body)
  if root_count == 1 {
    let branch_id = @ir.hot_region_get(func, body, 0)
    let branch = @ir.hot_node_get(func, branch_id)
    match branch.op {
      @ir.HotOp::Br => ()
      _ => return false
    }
    if !optimize_instructions_standalone_ref_get_desc_label_owner_is(
        func,
        branch.imm0,
        block_id,
      ) ||
      @ir.hot_child_count(func, branch_id) != 1 {
      return false
    }
    optimize_instructions_standalone_ref_get_desc_is_br_on_null_local_root(
      func,
      root_id,
      @ir.hot_child_get(func, branch_id, 0),
    )
  } else if root_count == 2 {
    let null_branch = @ir.hot_region_get(func, body, 0)
    let value_branch = @ir.hot_region_get(func, body, 1)
    if !optimize_instructions_standalone_ref_get_desc_is_br_on_null_local_root(
        func, root_id, null_branch,
      ) {
      return false
    }
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
  } else {
    false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_block_child_can_move_null_check(
  func : @ir.HotFunc,
  block_id : Int,
) -> Bool {
  if !optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
      func, block_id,
    ) {
    return false
  }
  let body = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body)
  if root_count == 0 {
    return false
  }
  let mut saw_internal_ref_branch = false
  for slot = 0; slot < root_count - 1; slot = slot + 1 {
    let root_id = @ir.hot_region_get(func, body, slot)
    if !optimize_instructions_standalone_ref_get_desc_node_has_no_results(
        func, root_id,
      ) {
      return false
    }
    if optimize_instructions_standalone_ref_get_desc_is_internal_br_on_null_trampoline_root(
        func, block_id, root_id,
      ) {
      saw_internal_ref_branch = true
      continue
    }
    if optimize_instructions_standalone_ref_get_desc_is_escaping_br_if_root(
        func, block_id, root_id,
      ) {
      continue
    }
    if optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func, block_id, root_id,
      ) {
      return false
    }
    if optimize_instructions_standalone_ref_get_desc_is_internal_br_on_non_null_root(
        func, block_id, root_id,
      ) {
      saw_internal_ref_branch = true
    }
  }
  let final_id = @ir.hot_region_get(func, body, root_count - 1)
  match @ir.hot_node_get(func, final_id).op {
    @ir.HotOp::LocalGet =>
      optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
        func, final_id,
      ) &&
      !optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func, block_id, final_id,
      )
    @ir.HotOp::RefNull =>
      saw_internal_ref_branch &&
      optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
        func, final_id,
      ) &&
      !optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func, block_id, final_id,
      )
    @ir.HotOp::Br | @ir.HotOp::BrTable =>
      optimize_instructions_standalone_ref_get_desc_node_has_no_results(
        func, final_id,
      ) &&
      !optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func, block_id, final_id,
      )
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail =>
      optimize_instructions_standalone_ref_get_desc_is_internal_br_on_cast_root(
        func, block_id, final_id,
      )
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_call_operand_is_nontrapping_leaf(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => @ir.hot_child_count(func, node_id) == 0
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_ref_null_leaf_is_known_null(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::RefNull =>
      @ir.hot_child_count(func, node_id) == 0 &&
      optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
        func, node_id,
      )
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_local_tee_child_is_known_null(
  func : @ir.HotFunc,
  tee_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, tee_id).op {
    @ir.HotOp::LocalTee => ()
    _ => return false
  }
  optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
    func, tee_id,
  ) &&
  @ir.hot_child_count(func, tee_id) == 1 &&
  optimize_instructions_standalone_ref_get_desc_ref_null_leaf_is_known_null(
    func,
    @ir.hot_child_get(func, tee_id, 0),
  )
}

///|
fn optimize_instructions_standalone_ref_get_desc_branch_free_block_child_is_known_null(
  func : @ir.HotFunc,
  block_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if !optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
      func, block_id,
    ) {
    return false
  }
  let body = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body)
  if root_count == 0 {
    return false
  }
  for slot = 0; slot < root_count - 1; slot = slot + 1 {
    let root_id = @ir.hot_region_get(func, body, slot)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Br
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrTable
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail => return false
      _ => ()
    }
    if !optimize_instructions_standalone_ref_get_desc_node_has_no_results(
        func, root_id,
      ) ||
      optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
        func, block_id, root_id,
      ) {
      return false
    }
  }
  let final_id = @ir.hot_region_get(func, body, root_count - 1)
  optimize_instructions_standalone_ref_get_desc_ref_null_leaf_is_known_null(
    func, final_id,
  ) &&
  !optimize_instructions_standalone_ref_get_desc_expr_has_disallowed_control_or_multivalue(
    func, block_id, final_id,
  )
}

///|
fn optimize_instructions_standalone_ref_get_desc_nullable_ref_leaf_can_move_null_check(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet | @ir.HotOp::GlobalGet =>
      @ir.hot_child_count(func, node_id) == 0 &&
      optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
        func, node_id,
      )
    _ => false
  }
}

///|
fn optimize_instructions_standalone_ref_get_desc_local_tee_child_can_move_null_check(
  func : @ir.HotFunc,
  tee_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, tee_id).op {
    @ir.HotOp::LocalTee => ()
    _ => return false
  }
  optimize_instructions_standalone_ref_get_desc_child_has_single_nullable_ref_result(
    func, tee_id,
  ) &&
  @ir.hot_child_count(func, tee_id) == 1 &&
  optimize_instructions_standalone_ref_get_desc_nullable_ref_leaf_can_move_null_check(
    func,
    @ir.hot_child_get(func, tee_id, 0),
  )
}

///|
fn optimize_instructions_standalone_ref_get_desc_call_child_can_move_null_check(
  func : @ir.HotFunc,
  call_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, call_id).op {
    @ir.HotOp::Call | @ir.HotOp::CallIndirect => ()
    _ => return false
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, call_id)) {
    [@lib.ValType::RefTypeValType(_)] => ()
    _ => return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, call_id); slot = slot + 1 {
    if !optimize_instructions_standalone_ref_get_desc_call_operand_is_nontrapping_leaf(
        func,
        @ir.hot_child_get(func, call_id, slot),
      ) {
      return false
    }
  }
  true
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
fn optimize_instructions_exact_descriptor_miss_operand_expr_is_straight_line(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
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
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef => return false
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if !optimize_instructions_exact_descriptor_miss_operand_expr_is_straight_line(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_exact_descriptor_miss_operand_can_drop_before_unreachable(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let body = @ir.hot_region_body_ref(func, node_id)
  for slot = 0; slot < @ir.hot_region_root_count(func, body); slot = slot + 1 {
    if !optimize_instructions_exact_descriptor_miss_operand_expr_is_straight_line(
        func,
        @ir.hot_region_get(func, body, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_exact_descriptor_miss_reference_call_can_drop_before_unreachable(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Call => ()
    _ => return false
  }
  optimize_instructions_exact_descriptor_miss_operand_expr_is_straight_line(
    func, node_id,
  )
}

///|
fn optimize_instructions_exact_descriptor_miss_descriptor_call_can_drop_before_unreachable(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Call => ()
    _ => return false
  }
  optimize_instructions_exact_descriptor_miss_operand_expr_is_straight_line(
    func, node_id,
  )
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
  if optimize_instructions_descriptor_expr_has_escaping_branch_control(
      func,
      cast_fact.descriptor_id,
    ) {
    return false
  }
  let (operand_nullable, operand_exact) = match
    optimize_instructions_ref_operand_matches_or_subtypes_heap(
      ctx,
      func,
      cast_fact.operand_id,
      cast_fact.target,
    ) {
    Some(info) => info
    None => return false
  }
  let descriptor_described_heap = optimize_instructions_descriptor_operand_exact_described_heap(
    ctx,
    func,
    cast_fact.descriptor_id,
  )
  let narrowed_target = match descriptor_described_heap {
    Some(described_heap) if optimize_instructions_heap_is_known_subtype(
        ctx,
        described_heap,
        cast_fact.target,
      ) => described_heap
    _ => cast_fact.target
  }
  let descriptor_exact = narrowed_target != cast_fact.target ||
    optimize_instructions_descriptor_operand_exactly_describes_target(
      ctx,
      func,
      cast_fact.descriptor_id,
      cast_fact.target,
    )
  let narrowed_nullable = cast_fact.nullable && operand_nullable
  ignore(operand_exact)
  let narrowed_exact = cast_fact.exact || descriptor_exact
  if narrowed_nullable == cast_fact.nullable &&
    narrowed_exact == cast_fact.exact &&
    narrowed_target == cast_fact.target {
    return false
  }
  let narrowed_instr = @lib.Instruction::ref_cast_desc_eq_type(
    @lib.RefType::new(narrowed_nullable, narrowed_target, exact=narrowed_exact),
  )
  let payload_id = @ir.hot_alloc_instr_payload(
    func,
    @ir.HotInstrPayload::new(narrowed_instr),
  )
  let narrowed = @ir.hot_build_node(
    func,
    @ir.hot_node_get(func, node_id).op,
    @ir.hot_type_intern_value(
      func,
      @lib.ValType::ref_type(
        @lib.RefType::new(
          narrowed_nullable,
          narrowed_target,
          exact=narrowed_exact,
        ),
      ),
    ),
    imm1=payload_id,
    children=[cast_fact.operand_id, cast_fact.descriptor_id],
  )
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, narrowed))
  @ir.hot_delete_node(func, narrowed)
  pass_mark_mutated(ctx, func)
  true
}

///|
fn optimize_instructions_ref_operand_matches_or_subtypes_heap(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> (Bool, Bool)? {
  OiRefProducerFact::from_node(ctx, func, node_id).matches_or_subtypes_heap(
    ctx, target,
  )
}

///|
fn optimize_instructions_heap_is_known_subtype(
  ctx : HotPassContext,
  source : @lib.HeapType,
  target : @lib.HeapType,
) -> Bool {
  if source == target {
    return true
  }
  let module_ctx = match ctx.module_ctx {
    Some(module_ctx) => module_ctx
    None => return false
  }
  optimize_instructions_heap_is_known_subtype_with_fuel(
    module_ctx, source, target, 64,
  )
}

///|
fn optimize_instructions_heap_is_known_subtype_with_fuel(
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
        if optimize_instructions_heap_is_known_subtype_with_fuel(
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
fn optimize_instructions_descriptor_skip_region_must_preserve_operand_order(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for slot = 0
      slot < @ir.hot_region_root_count(func, region_ref)
      slot = slot + 1 {
    if optimize_instructions_descriptor_skip_must_preserve_operand_order(
        func,
        @ir.hot_region_get(func, region_ref, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_descriptor_skip_must_preserve_operand_order(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
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
    | @ir.HotOp::ThrowRef => return true
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      if optimize_instructions_descriptor_skip_region_must_preserve_operand_order(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
    @ir.HotOp::If => {
      if optimize_instructions_descriptor_skip_region_must_preserve_operand_order(
          func,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          if optimize_instructions_descriptor_skip_region_must_preserve_operand_order(
              func, region_ref,
            ) {
            return true
          }
        None => ()
      }
    }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if optimize_instructions_descriptor_skip_must_preserve_operand_order(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn optimize_instructions_descriptor_operand_exactly_describes_target(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  target : @lib.HeapType,
) -> Bool {
  OiDescriptorTypeFact::from_node(ctx, func, node_id).exactly_describes(target)
}

///|
fn optimize_instructions_descriptor_operand_exact_described_heap(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.HeapType? {
  OiDescriptorTypeFact::from_node(ctx, func, node_id).exact_described_heap
}

///|
fn optimize_instructions_ref_operand_is_exact_heap(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  heap : @lib.HeapType,
) -> Bool {
  OiRefProducerFact::from_node(ctx, func, node_id).exact_heap(heap)
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
fn optimize_instructions_descriptor_operand_can_erase(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  optimize_instructions_is_side_effect_free_expr(func, dead, node_id) ||
  optimize_instructions_node_effects_are_pure(ctx, func, node_id) ||
  optimize_instructions_descriptor_operand_allocation_can_erase(func, node_id) ||
  optimize_instructions_ref_get_desc_operand_can_erase(func, dead, node_id) ||
  (
    ctx.traps_never_happen &&
    (
      optimize_instructions_ref_as_non_null_descriptor_operand_can_erase_traps_never_happen(
        func, dead, node_id,
      ) ||
      optimize_instructions_ref_get_desc_operand_can_erase_traps_never_happen(
        func, dead, node_id,
      )
    )
  )
}

///|
fn optimize_instructions_descriptor_operand_allocation_can_erase(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructNewDefault(_)) => true
    _ => false
  }
}

///|
fn optimize_instructions_descriptor_nullable_child_can_erase_traps_never_happen(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  if optimize_instructions_is_side_effect_free_expr(func, dead, node_id) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => {
      let body = @ir.hot_region_body_ref(func, node_id)
      if @ir.hot_region_root_count(func, body) == 0 ||
        optimize_instructions_descriptor_expr_has_escaping_branch_control(
          func, node_id,
        ) {
        return false
      }
      for slot = 0
          slot < @ir.hot_region_root_count(func, body)
          slot = slot + 1 {
        if !optimize_instructions_descriptor_expr_is_effect_free_allowing_internal_control(
            func,
            dead,
            node_id,
            @ir.hot_region_get(func, body, slot),
          ) {
          return false
        }
      }
      true
    }
    @ir.HotOp::If =>
      optimize_instructions_descriptor_nullable_if_child_can_move_null_check(
        func, dead, node_id,
      )
    _ => false
  }
}

///|
fn optimize_instructions_descriptor_expr_is_effect_free_allowing_internal_control(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  owner_id : Int,
  node_id : Int,
) -> Bool {
  if optimize_instructions_is_side_effect_free_expr(func, dead, node_id) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf =>
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::BrTable => {
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ) {
        return false
      }
      for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
        if !optimize_instructions_descriptor_label_is_internal_to_expr(
            func, owner_id, label_id,
          ) {
          return false
        }
      }
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if !optimize_instructions_descriptor_label_is_internal_to_expr(
          func,
          owner_id,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::Block => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for slot = 0
          slot < @ir.hot_region_root_count(func, body)
          slot = slot + 1 {
        if !optimize_instructions_descriptor_expr_is_effect_free_allowing_internal_control(
            func,
            dead,
            owner_id,
            @ir.hot_region_get(func, body, slot),
          ) {
          return false
        }
      }
    }
    @ir.HotOp::Drop => if node.child_count != 1 { return false }
    _ => return false
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if !optimize_instructions_descriptor_expr_is_effect_free_allowing_internal_control(
        func,
        dead,
        owner_id,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn optimize_instructions_descriptor_operand_should_localize_when_skipped(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Call | @ir.HotOp::CallRef => return true
    _ => ()
  }
  match OiRefGetDescFact::from_node(func, node_id) {
    Some(_) => true
    None => false
  }
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
fn optimize_instructions_ref_get_desc_operand_can_erase(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiRefGetDescFact::from_node(func, node_id) {
    Some(fact) => fact.operand_can_erase(func, dead)
    None => false
  }
}

///|
fn optimize_instructions_ref_as_non_null_descriptor_operand_can_erase_traps_never_happen(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::RefAsNonNull) => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  optimize_instructions_descriptor_nullable_child_can_erase_traps_never_happen(
    func,
    dead,
    @ir.hot_child_get(func, node_id, 0),
  )
}

///|
fn optimize_instructions_ref_get_desc_operand_can_erase_traps_never_happen(
  func : @ir.HotFunc,
  dead : @bitset.BitSet,
  node_id : Int,
) -> Bool {
  match OiRefGetDescFact::from_node(func, node_id) {
    Some(fact) => fact.operand_can_erase_traps_never_happen(func, dead)
    None => false
  }
}

///|
fn optimize_instructions_descriptor_operand_traps_without_effects(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable => return true
    _ => ()
  }
  match OiRefGetDescFact::from_node(func, node_id) {
    Some(fact) => fact.traps_without_effects(func)
    None => false
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
  if optimize_instructions_descriptor_expr_has_branch_control(func, operand_id) {
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
  if optimize_instructions_descriptor_expr_has_escaping_branch_control(
      func,
      cast_fact.descriptor_id,
    ) {
    return false
  }
  let operand_exact = match
    optimize_instructions_ref_operand_matches_or_subtypes_heap(
      ctx,
      func,
      cast_fact.operand_id,
      cast_fact.target,
    ) {
    Some((_, exact)) => exact
    None => false
  }
  let descriptor_described_heap = optimize_instructions_descriptor_operand_exact_described_heap(
    ctx,
    func,
    cast_fact.descriptor_id,
  )
  let narrowed_target = match descriptor_described_heap {
    Some(described_heap) if optimize_instructions_heap_is_known_subtype(
        ctx,
        described_heap,
        cast_fact.target,
      ) => described_heap
    _ => cast_fact.target
  }
  let descriptor_exact = narrowed_target != cast_fact.target ||
    optimize_instructions_descriptor_operand_exactly_describes_target(
      ctx,
      func,
      cast_fact.descriptor_id,
      cast_fact.target,
    )
  ignore(operand_exact)
  let narrowed_exact = cast_fact.exact || descriptor_exact
  let narrowed_ref_type = @lib.RefType::new(
    false,
    narrowed_target,
    exact=narrowed_exact,
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
    @ir.hot_node_get(func, cast_id).op,
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
fn optimize_instructions_ref_eq_same_local_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet => Some(@ir.hot_node_get(func, node_id).imm0)
    @ir.HotOp::RefCast => {
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
                  } else if ref_type.get_heap_type() == target ||
                    (
                      ref_type.get_heap_type() ==
                      @lib.HeapType::abs(@lib.AbsHeapType::i31()) &&
                      optimize_instructions_ref_i31_matches_target(target)
                    ) ||
                    optimize_instructions_abs_struct_array_matches_target(
                      ref_type.get_heap_type(),
                      target,
                    ) {
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
    _ => None
  }
}

///|
fn optimize_instructions_ref_eq_operands_are_same_local(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_ref_eq_same_local_operand(ctx, func, lhs_id),
      optimize_instructions_ref_eq_same_local_operand(ctx, func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn optimize_instructions_ref_eq_same_local_as_non_null_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int, Int)? {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet => Some((@ir.hot_node_get(func, node_id).imm0, -1))
    _ =>
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.Instruction::RefAsNonNull) => {
          if @ir.hot_child_count(func, node_id) != 1 {
            return None
          }
          let child_id = @ir.hot_child_get(func, node_id, 0)
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::LocalGet => {
              let local_idx = @ir.hot_node_get(func, child_id).imm0
              match @ir.hot_local_type(func, local_idx) {
                Some(@lib.ValType::RefTypeValType(ref_type)) =>
                  if ref_type.is_non_nullable() {
                    Some((local_idx, -1))
                  } else {
                    Some((local_idx, node_id))
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
}

///|
fn optimize_instructions_ref_eq_same_local_as_non_null_trap(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Int? {
  match
    (
      optimize_instructions_ref_eq_same_local_as_non_null_operand(func, lhs_id),
      optimize_instructions_ref_eq_same_local_as_non_null_operand(func, rhs_id),
    ) {
    (Some((lhs, lhs_trap)), Some((rhs, rhs_trap))) if lhs == rhs =>
      if lhs_trap >= 0 {
        Some(lhs_trap)
      } else if rhs_trap >= 0 {
        Some(rhs_trap)
      } else {
        None
      }
    _ => None
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
  let descriptor_eval = if optimize_instructions_descriptor_operand_should_localize_when_skipped(
      func, descriptor_id,
    ) {
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
  @ir.effects_is_pure(effects.node_masks[node_id])
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
fn optimize_instructions_ref_i31_local_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
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
fn optimize_instructions_ref_eq_operands_are_same_i31_local(
  func : @ir.HotFunc,
  lhs_id : Int,
  rhs_id : Int,
) -> Bool {
  match
    (
      optimize_instructions_ref_i31_local_operand(func, lhs_id),
      optimize_instructions_ref_i31_local_operand(func, rhs_id),
    ) {
    (Some(lhs), Some(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn optimize_instructions_ref_i31_const_operand(
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
  let lhs_id = @ir.hot_child_get(func, node_id, 0)
  let rhs_id = @ir.hot_child_get(func, node_id, 1)
  if optimize_instructions_ref_eq_operands_are_same_local(
      ctx, func, lhs_id, rhs_id,
    ) ||
    optimize_instructions_ref_eq_operands_are_same_i31_local(
      func, lhs_id, rhs_id,
    ) {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(1),
    )
    return true
  }
  match
    optimize_instructions_ref_eq_same_local_as_non_null_trap(
      func, lhs_id, rhs_id,
    ) {
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
  match
    (
      optimize_instructions_ref_i31_const_operand(func, dead, lhs_id),
      optimize_instructions_ref_i31_const_operand(func, dead, rhs_id),
    ) {
    (Some(@lib.I32(lhs)), Some(@lib.I32(rhs))) => {
      optimize_instructions_replace_with_const_i32(
        ctx,
        func,
        node_id,
        if lhs == rhs {
          @lib.I32(1)
        } else {
          @lib.I32(0)
        },
      )
      return true
    }
    _ => ()
  }
  if (
      optimize_instructions_ref_is_known_non_null_i31(func, lhs_id) &&
      optimize_instructions_ref_cannot_be_i31(func, rhs_id)
    ) ||
    (
      optimize_instructions_ref_is_known_non_null_i31(func, rhs_id) &&
      optimize_instructions_ref_cannot_be_i31(func, lhs_id)
    ) ||
    optimize_instructions_ref_local_heaps_are_impossible_equal(
      func, lhs_id, rhs_id,
    ) {
    optimize_instructions_replace_ref_eq_impossible_with_const_i32(
      ctx, func, node_id, lhs_id, rhs_id,
    )
    return true
  }
  if optimize_instructions_ref_is_null_operand(func, lhs_id) &&
    optimize_instructions_ref_is_null_operand(func, rhs_id) {
    optimize_instructions_replace_with_const_i32(
      ctx,
      func,
      node_id,
      @lib.I32(1),
    )
    return true
  }
  if optimize_instructions_ref_is_null_operand(func, lhs_id) {
    if optimize_instructions_ref_is_known_non_null(func, rhs_id) {
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
      optimize_instructions_replace_with_ref_is_null(ctx, func, node_id, rhs_id)
    }
    return true
  }
  if optimize_instructions_ref_is_null_operand(func, rhs_id) {
    if optimize_instructions_ref_is_known_non_null(func, lhs_id) {
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
      optimize_instructions_replace_with_ref_is_null(ctx, func, node_id, lhs_id)
    }
    return true
  }
  false
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
  if !optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) {
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
      if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) ||
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
      optimize_instructions_local_get_id(func, dead, lhs_id),
      optimize_instructions_local_get_id(func, dead, rhs_id),
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
      optimize_instructions_local_get_id(func, dead, lhs_id),
      optimize_instructions_local_get_id(func, dead, rhs_id),
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
      if optimize_instructions_is_side_effect_free_expr(func, dead, drop_id) ||
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
      if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) ||
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
      if optimize_instructions_is_side_effect_free_expr(func, dead, lhs_id) ||
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
        if !optimize_instructions_node_is_live(func, dead, operand_id) {
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
      if optimize_instructions_is_remainder_instr(func, dead, rhs_id) {
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
      if optimize_instructions_is_remainder_instr(func, dead, lhs_id) {
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
      if optimize_instructions_is_remainder_instr(func, dead, rhs_id) {
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
      if optimize_instructions_is_remainder_instr(func, dead, lhs_id) {
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
    if optimize_instructions_node_is_live(func, dead, root_id) {
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
  if !optimize_instructions_node_is_live(func, dead, node_id) {
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
    if !optimize_instructions_node_is_live(func, dead, child_id) {
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
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
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
            ctx, func, dead, node_id, initial_instr, initial_lhs, initial_rhs,
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
          )
        let current = func.nodes[node_id]
        let canonicalized = match current.op {
          @ir.HotOp::Binary => {
            let current_instr = func.instr_payloads[current.imm0].instr
            if !optimize_instructions_is_commutative_instr(current_instr) {
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
          node_id,
          func.instr_payloads[node.imm0].instr,
          func.children[node.child_base],
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
              ctx, func, dead, node_id, current_instr, current_lhs, current_rhs,
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
            let canonicalized = if optimize_instructions_is_commutative_instr(
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
      optimize_instructions_try_fold_ref_is_null(ctx, func, node_id)
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
fn optimize_instructions_func_has_unsupported_aggregate_atomic_receiver(
  func : @ir.HotFunc,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_exact_instr(func, node_id) {
      Some(@lib.Instruction::StructAtomicRmw(_, _, _))
      | Some(@lib.Instruction::StructAtomicCmpxchg(_, _)) =>
        if @ir.hot_child_count(func, node_id) == 0 {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn optimize_instructions_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if optimize_instructions_func_has_unsupported_aggregate_atomic_receiver(func) {
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
    "detail:optimize-instructions:scan-sign-ext-facts",
  )
  optimize_instructions_scan_sign_ext_facts(func, dead, scratch)
  perf_stop_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:scan-sign-ext-facts",
    sign_ext_start_us,
  )
  let unsigned_max_start_us = perf_start_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:scan-unsigned-max-facts",
  )
  optimize_instructions_scan_unsigned_max_facts(func, dead, scratch)
  perf_stop_timer_opt(
    ctx.perf,
    "detail:optimize-instructions:scan-unsigned-max-facts",
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
