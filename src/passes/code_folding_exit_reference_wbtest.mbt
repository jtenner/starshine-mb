///|
/// Pre-review recursive label-scan control for the dedicated benchmark lane.
fn code_folding_nested_exit_reference(
  func : @ir.HotFunc,
  node_id : Int32,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if @ir.hot_is_control_node(func, node_id) &&
    !(@ir.hot_node_get(func, node_id).op is @ir.HotOp::Loop) &&
    pass_label_is_used(
      @ir.hot_control_node_label(func, node_id),
      pass_compute_label_used(func),
    ) {
    // A branch to this control's label resumes after it, even if a later
    // body root returns or traps on the non-branching path.
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef => true
    @ir.HotOp::Drop =>
      @ir.hot_child_count(func, node_id) == 1 &&
      code_folding_nested_exit_reference(
        func,
        @ir.hot_child_get(func, node_id, 0),
      )
    @ir.HotOp::Try | @ir.HotOp::TryTable => false
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for i = 0; i < @ir.hot_region_root_count(func, body_ref); i = i + 1 {
        if code_folding_nested_exit_reference(
            func,
            @ir.hot_region_get(func, body_ref, i),
          ) {
          return true
        }
      }
      false
    }
    @ir.HotOp::If => {
      let else_ref = match @ir.hot_region_else_ref(func, node_id) {
        Some(ref_) => ref_
        None => return false
      }
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      let then_count = @ir.hot_region_root_count(func, then_ref)
      let else_count = @ir.hot_region_root_count(func, else_ref)
      if then_count == 0 || else_count == 0 {
        false
      } else {
        let mut then_exits = false
        for i = 0; i < then_count; i = i + 1 {
          if code_folding_nested_exit_reference(
              func,
              @ir.hot_region_get(func, then_ref, i),
            ) {
            then_exits = true
          }
        }
        let mut else_exits = false
        for i = 0; i < else_count; i = i + 1 {
          if code_folding_nested_exit_reference(
              func,
              @ir.hot_region_get(func, else_ref, i),
            ) {
            else_exits = true
          }
        }
        then_exits && else_exits
      }
    }
    _ => false
  }
}
