///|
pub fn code_pushing_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("code-pushing", invalidates=[
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
pub fn code_pushing_summary() -> String {
  "Sink safe local computations into the control-flow arm that actually consumes them."
}

///|
fn code_pushing_node_is_const_like(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Const | @ir.HotOp::RefNull | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn code_pushing_count_local_gets_in_node(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut count = match node.op {
    @ir.HotOp::LocalGet if node.imm0 == local_id => 1
    _ => 0
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    count += code_pushing_count_local_gets_in_node(
      func,
      @ir.hot_child_get(func, node_id, slot),
      local_id,
    )
  }
  count
}

///|
fn code_pushing_count_local_writes_in_node(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut count = match node.op {
    @ir.HotOp::LocalSet if node.imm0 == local_id => 1
    @ir.HotOp::LocalTee if node.imm0 == local_id => 1
    _ => 0
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    count += code_pushing_count_local_writes_in_node(
      func,
      @ir.hot_child_get(func, node_id, slot),
      local_id,
    )
  }
  count
}

///|
fn code_pushing_count_local_gets_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
) -> Int {
  let mut count = 0
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    count += code_pushing_count_local_gets_in_node(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      local_id,
    )
  }
  count
}

///|
fn code_pushing_count_local_writes_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
) -> Int {
  let mut count = 0
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    count += code_pushing_count_local_writes_in_node(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      local_id,
    )
  }
  count
}

///|
fn code_pushing_count_local_gets_in_if_arms(
  func : @ir.HotFunc,
  if_id : Int,
  local_id : Int,
) -> (Int, Int) {
  let then_gets = code_pushing_count_local_gets_in_region(
    func,
    @ir.hot_region_then_ref(func, if_id),
    local_id,
  )
  let else_gets = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) =>
      code_pushing_count_local_gets_in_region(func, else_ref, local_id)
    None => 0
  }
  (then_gets, else_gets)
}

///|
fn code_pushing_all_gets_are_in_if_arms(
  func : @ir.HotFunc,
  if_id : Int,
  local_id : Int,
) -> Bool {
  let total_gets = code_pushing_count_local_gets_in_region(
    func,
    @ir.HotRegionRef::root(),
    local_id,
  )
  if total_gets == 0 {
    return false
  }
  let (then_gets, else_gets) = code_pushing_count_local_gets_in_if_arms(
    func, if_id, local_id,
  )
  then_gets + else_gets == total_gets
}

///|
fn code_pushing_has_single_local_write(
  func : @ir.HotFunc,
  local_id : Int,
) -> Bool {
  code_pushing_count_local_writes_in_region(
    func,
    @ir.HotRegionRef::root(),
    local_id,
  ) == 1
}

///|
fn code_pushing_inline_local_gets_in_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  replacement : @ir.HotNode,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet if node.imm0 == local_id => {
      pass_replace_node(ctx, func, node_id, replacement)
      return true
    }
    _ => ()
  }
  let mut changed = false
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    changed = code_pushing_inline_local_gets_in_node(
        ctx,
        func,
        @ir.hot_child_get(func, node_id, slot),
        local_id,
        replacement,
      ) ||
      changed
  }
  changed
}

///|
fn code_pushing_inline_local_gets_in_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
  replacement : @ir.HotNode,
) -> Bool {
  let mut changed = false
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    changed = code_pushing_inline_local_gets_in_node(
        ctx,
        func,
        @ir.hot_region_get(func, region_ref, idx),
        local_id,
        replacement,
      ) ||
      changed
  }
  changed
}

///|
fn code_pushing_try_sink_set_into_if_then(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  if set_idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let set_id = @ir.hot_region_get(func, region_ref, set_idx)
  if set_id < 0 || !@ir.hot_node_is_live(func, set_id) {
    return false
  }
  let set_node = @ir.hot_node_get(func, set_id)
  match set_node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, set_id) != 0 {
    return false
  }
  let value_id = @ir.hot_child_get(func, set_id, 0)
  if !code_pushing_node_is_const_like(func, value_id) {
    return false
  }

  let if_id = @ir.hot_region_get(func, region_ref, set_idx + 1)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, if_id) != 0 {
    return false
  }
  let local_id = set_node.imm0
  if !code_pushing_has_single_local_write(func, local_id) ||
    !code_pushing_all_gets_are_in_if_arms(func, if_id, local_id) {
    return false
  }

  let (then_gets, else_gets) = code_pushing_count_local_gets_in_if_arms(
    func, if_id, local_id,
  )
  let replacement = @ir.hot_node_get(func, value_id)
  let mut inlined = false
  if then_gets > 0 {
    inlined = code_pushing_inline_local_gets_in_region(
      ctx,
      func,
      @ir.hot_region_then_ref(func, if_id),
      local_id,
      replacement,
    ) ||
    inlined
  }
  if else_gets > 0 {
    match @ir.hot_region_else_ref(func, if_id) {
      Some(else_ref) =>
        inlined = code_pushing_inline_local_gets_in_region(
          ctx, func, else_ref, local_id, replacement,
        ) ||
        inlined
      None => ()
    }
  }
  if !inlined {
    return false
  }
  ignore(pass_splice_region(ctx, func, region_ref, set_idx, 1, []))
  true
}

///|
fn code_pushing_scan_region_once(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    if code_pushing_try_sink_set_into_if_then(ctx, func, region_ref, idx) {
      return true
    }
    idx += 1
  }

  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) {
          return true
        }
      @ir.HotOp::If => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if code_pushing_scan_region_once(ctx, func, else_ref) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::Try => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) {
          return true
        }
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            if code_pushing_scan_region_once(ctx, func, catch_ref) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) {
          return true
        }
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
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
fn code_pushing_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let mut changed_any = false
  let mut changed_round = true
  while changed_round {
    changed_round = code_pushing_scan_region_once(
      ctx,
      func,
      @ir.HotRegionRef::root(),
    )
    if changed_round {
      changed_any = true
    }
  }
  if changed_any {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
