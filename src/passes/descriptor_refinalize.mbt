///|
fn pass_instrs_have_descriptor_branches(
  instrs : Array[@lib.Instruction],
) -> Bool {
  for instr in instrs {
    match instr {
      @lib.BrOnCastDescEq(_, _, _) | @lib.BrOnCastDescEqFail(_, _, _) =>
        return true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if pass_instrs_have_descriptor_branches(body) {
          return true
        }
      @lib.If(_, yes, no) => {
        if pass_instrs_have_descriptor_branches(yes) {
          return true
        }
        if no is Some(body) && pass_instrs_have_descriptor_branches(body) {
          return true
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if pass_instrs_have_descriptor_branches(body) {
          return true
        }
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          if pass_instrs_have_descriptor_branches(body) {
            return true
          }
        }
      }
      _ => ()
    }
  }
  false
}

///|
// A null descriptor traps before its branch can be taken. Give the replacement
// an uninhabitable reference result, preserving every operand evaluation. This
// is shared result recomputation: local refinement must never replace that
// bottom result with the nullable source annotation (#8975).
fn pass_refinalize_descriptor_bottoms(
  func : @ir.HotFunc,
  module_ctx : @ir.HotModuleContext,
) -> Bool {
  let count = @ir.hot_node_count(func)
  let seen = Array::make(count, false)
  let nulls = Array::make(count, false)
  let never = Array::make(count, false)
  let branches = Array::make(count, false)
  let work : Array[(Int, Bool)] = []
  for root in @ir.hot_root_span(func) {
    work.push((root, false))
  }
  let mut changed = false
  while !work.is_empty() {
    let (node, ready) = work.pop().unwrap()
    if node < 0 || !@ir.hot_node_is_live(func, node) {
      continue
    }
    if !ready {
      if seen[node] {
        continue
      }
      seen[node] = true
      work.push((node, true))
      for child in @ir.hot_child_span(func, node) {
        work.push((child, false))
      }
      continue
    }
    let data = @ir.hot_node_get(func, node)
    let children = @ir.hot_child_span(func, node)
    branches[node] = (@ir.hot_node_flags(func, node) & @ir.HOT_FLAG_BRANCH) !=
      0U ||
      data.op is @ir.HotOp::Try ||
      data.op is @ir.HotOp::TryTable ||
      data.op is @ir.HotOp::Continuation ||
      children.any(fn(child) { child >= 0 && branches[child] })
    nulls[node] = data.op is @ir.HotOp::RefNull
    never[node] = match data.op {
      @ir.HotOp::Unreachable
      | @ir.HotOp::Return
      | @ir.HotOp::ReturnCall
      | @ir.HotOp::ReturnCallIndirect
      | @ir.HotOp::ReturnCallRef
      | @ir.HotOp::Throw
      | @ir.HotOp::ThrowRef => true
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        !branches[node] &&
        children.any(fn(child) { child >= 0 && never[child] })
      @ir.HotOp::If =>
        (children[0] >= 0 && never[children[0]]) ||
        (
          !branches[node] &&
          children.length() == 3 &&
          children[1] >= 0 &&
          children[2] >= 0 &&
          never[children[1]] &&
          never[children[2]]
        )
      @ir.HotOp::Try | @ir.HotOp::TryTable => false
      _ => children.any(fn(child) { child >= 0 && never[child] })
    }
    if @ir.hot_node_exact_instr(func, node) is Some(@lib.RefAsNonNull) &&
      children.length() == 1 &&
      children[0] >= 0 &&
      nulls[children[0]] {
      never[node] = true
    }
    match @ir.hot_type_results(func, data.ty) {
      [@lib.RefTypeValType(ref_type)] =>
        match ref_type.get_heap_type() {
          @lib.AbsHeapTypeHeapType(@lib.NoneAbsHeapType)
          | @lib.SharedAbsHeapTypeHeapType(@lib.NoneAbsHeapType) =>
            if ref_type.is_nullable() {
              nulls[node] = true
            } else {
              never[node] = true
            }
          _ => ()
        }
      _ => ()
    }
    if never[node] &&
      !branches[node] &&
      (data.op is @ir.HotOp::Block || data.op is @ir.HotOp::Loop) {
      let declared = match @ir.hot_type_get(func, data.ty) {
        @ir.BlockResult(@lib.ValTypeBlockType(@lib.RefTypeValType(ref_type)))
        | @ir.BlockResultResolved(
          @lib.ValTypeBlockType(@lib.RefTypeValType(ref_type)),
          [],
          _
        ) => Some(ref_type)
        _ => None
      }
      if declared is Some(ref_type) {
        let gc_shared = match ref_type.get_heap_type() {
          @lib.HeapType(index) =>
            match @ir.hot_module_resolve_subtype(module_ctx, index) {
              Some(subtype) =>
                match subtype.get_comptype() {
                  @lib.StructCompType(_) | @lib.ArrayCompType(_) =>
                    Some(subtype.metadata().is_shared())
                  _ => None
                }
              None => None
            }
          @lib.AbsHeapTypeHeapType(@lib.NoneAbsHeapType) => Some(false)
          @lib.SharedAbsHeapTypeHeapType(@lib.NoneAbsHeapType) => Some(true)
          _ => None
        }
        if gc_shared is Some(shared) {
          let bottom = @lib.RefType::new(
            false,
            if shared {
              @lib.HeapType::shared_abs(@lib.AbsHeapType::none())
            } else {
              @lib.HeapType::abs(@lib.AbsHeapType::none())
            },
          )
          if bottom != ref_type {
            @ir.hot_control_result_type_set(
              func,
              node,
              @ir.hot_type_intern_block_result(
                func,
                @lib.BlockType::val_type(@lib.ValType::ref_type(bottom)),
              ),
            )
            changed = true
          }
        }
      }
    }
    let target = match @ir.hot_node_exact_instr(func, node) {
      Some(@lib.BrOnCastDescEq(_, _, target))
      | Some(@lib.BrOnCastDescEqFail(_, _, target)) => target
      _ => continue
    }
    if children.length() < 2 {
      continue
    }
    let descriptor = children[children.length() - 1]
    let source = children[children.length() - 2]
    if descriptor < 0 || source < 0 {
      continue
    }
    if !nulls[descriptor] && !never[descriptor] && !never[source] {
      continue
    }
    let shared = match target.get_heap_type() {
      @lib.HeapType(type_idx) =>
        match @ir.hot_module_resolve_subtype(module_ctx, type_idx) {
          Some(subtype) => subtype.metadata().is_shared()
          None => continue
        }
      heap => heap.is_shared()
    }
    let bottom = @lib.ValType::ref_type(
      @lib.RefType::new(
        false,
        if shared {
          @lib.HeapType::shared_abs(@lib.AbsHeapType::none())
        } else {
          @lib.HeapType::abs(@lib.AbsHeapType::none())
        },
      ),
    )
    // Earlier label payloads are borrowed from the enclosing operand stack.
    // Only the source and descriptor are consumed by this instruction.
    let body = [
      @ir.hot_build_drop(func, source),
      @ir.hot_build_drop(func, descriptor),
    ]
    body.push(@ir.hot_build_unreachable(func))
    @ir.hot_node_promote_to_block(
      func,
      node,
      @lib.BlockType::val_type(bottom),
      body,
    )
    never[node] = true
    branches[node] = children.any(fn(child) { branches[child] })
    changed = true
  }
  changed
}

///|
// Refining a control result to non-null bottom also requires discarding the
// linear tail after a terminator. Dead explicit values still participate in
// Wasm stack validation, even when their producer cannot execute.
fn pass_refinalize_descriptor_trim_dead_tail(
  instrs : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  for instr in instrs {
    out.push(
      pass_lower_map_children(instr, pass_refinalize_descriptor_trim_dead_tail),
    )
    if run_hot_pipeline_raw_simplify_locals_instr_is_unconditional_terminator(
        instr,
      ) {
      break
    }
  }
  out
}

///|
fn pass_refinalize_descriptor_func(
  mod_ : @lib.Module,
  func_idx : @lib.FuncIdx,
  original : @lib.Func,
  module_ctx : @ir.HotModuleContext,
) -> (@lib.Func, Bool) {
  let @lib.Func(_, @lib.Expr(body)) = original
  if !pass_instrs_have_descriptor_branches(body) {
    return (original, false)
  }
  let hot = match
    @ir.hot_lift_func_with_context_result(mod_, func_idx, module_ctx) {
    Ok(hot) => hot
    Err(_) => return (original, false)
  }
  if pass_refinalize_descriptor_bottoms(hot, module_ctx) {
    let @lib.Func(locals, @lib.Expr(body)) = @ir.hot_lower_func(hot)
    (
      @lib.Func::new(
        locals,
        @lib.Expr::new(pass_refinalize_descriptor_trim_dead_tail(body)),
      ),
      true,
    )
  } else {
    (original, false)
  }
}
