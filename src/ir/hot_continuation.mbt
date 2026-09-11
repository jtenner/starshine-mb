///|
// Continuation opcodes retain their exact type/tag payload in imm0. The imm1
// branch table holds stable handler label identities, in on-label order; its
// default entry is unused. Raw binary label depths are reconstructed at lowering.
fn hot_continuation_handlers(instr : Instruction) -> Array[@lib.ResumeHandler] {
  match instr {
    Instruction::Resume(_, handlers)
    | Instruction::ResumeThrow(_, _, handlers)
    | Instruction::ResumeThrowRef(_, handlers) => handlers
    _ => []
  }
}

///|
fn hot_continuation_with_handler_labels(
  instr : Instruction,
  labels : Array[LabelIdx],
) -> Instruction {
  let mut cursor = 0
  let handlers = hot_continuation_handlers(instr).map(fn(handler) {
    match handler {
      @lib.ResumeOnLabel(tag, _) => {
        let label = labels[cursor]
        cursor += 1
        @lib.ResumeHandler::on_label(tag, label)
      }
      @lib.ResumeOnSwitch(_) => handler
    }
  })
  match instr {
    Instruction::Resume(type_idx, _) => Instruction::resume_(type_idx, handlers)
    Instruction::ResumeThrow(type_idx, tag, _) =>
      Instruction::resume_throw(type_idx, tag, handlers)
    Instruction::ResumeThrowRef(type_idx, _) =>
      Instruction::resume_throw_ref(type_idx, handlers)
    _ => instr
  }
}

///|
pub fn hot_continuation_targets(
  func : HotFunc,
  node_id : NodeId,
) -> Array[LabelId] {
  let node = hot_node_get(func, node_id)
  if node.op != HotOp::Continuation {
    return []
  }
  hot_branch_table_targets(func, node.imm1).copy()
}

///|
pub fn hot_continuation_targets_set(
  func : HotFunc,
  node_id : NodeId,
  targets : Array[LabelId],
) -> Unit {
  let node = hot_node_get(func, node_id)
  if node.op != HotOp::Continuation {
    abort("continuation target mutation requires a continuation node")
  }
  for target in targets {
    if target != HOT_IMPLICIT_FUNCTION_LABEL && !hot_label_is_live(func, target) {
      abort("continuation handler target must be live")
    }
  }
  let table = hot_alloc_branch_table(
    func,
    HotBranchTable::new(targets.copy(), HOT_IMPLICIT_FUNCTION_LABEL),
  )
  hot_node_set(func, node_id, { ..node, imm1: table, })
}

///|
fn cfg_expression_continuation_targets(
  func : HotFunc,
  root : NodeId,
  cache : Array[Array[LabelId]?],
) -> Array[LabelId] {
  if cache.is_empty() {
    return []
  }
  let pending = [(root, false)]
  while !pending.is_empty() {
    let (node, finish) = pending.pop().unwrap()
    if node < 0 || cache[node] is Some(_) {
      continue
    }
    let children = if hot_is_control_node(func, node) {
      if hot_node_get(func, node).op == HotOp::If {
        [hot_child_get(func, node, 0)]
      } else {
        []
      }
    } else {
      hot_child_span(func, node)
    }
    if !finish {
      pending.push((node, true))
      for child in children {
        if child >= 0 && cache[child] is None {
          pending.push((child, false))
        }
      }
    } else {
      let targets = hot_continuation_targets(func, node)
      for child in children {
        if child < 0 {
          continue
        }
        for target in cache[child].unwrap() {
          if !targets.contains(target) {
            targets.push(target)
          }
        }
      }
      cache[node] = Some(targets)
    }
  }
  cache[root].unwrap()
}
