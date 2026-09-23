///|
fn tail_call_label_exits_function(
  label : @lib.LabelIdx,
  tail_labels : Array[Bool],
) -> Bool {
  let @lib.LabelIdx(raw) = label
  let index = tail_labels.length() - 1 - raw.to_int()
  index >= 0 && index < tail_labels.length() && tail_labels[index]
}

///|
fn tail_call_pure_selector(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.LocalGet(_) | @lib.I32Const(_) | @lib.I64Const(_) => true
    _ => false
  }
}

///|
fn tail_call_transfer_after(
  instrs : Array[@lib.Instruction],
  index : Int,
  is_tail : Bool,
  tail_labels : Array[Bool],
) -> Bool {
  if index + 1 >= instrs.length() {
    return is_tail
  }
  match instrs[index + 1] {
    @lib.Return => true
    @lib.Br(label) => tail_call_label_exits_function(label, tail_labels)
    next if tail_call_pure_selector(next) && index + 2 == instrs.length() - 1 =>
      match instrs[index + 2] {
        @lib.BrIf(label) =>
          is_tail && tail_call_label_exits_function(label, tail_labels)
        @lib.BrTable(targets, default) => {
          if !is_tail || !tail_call_label_exits_function(default, tail_labels) {
            return false
          }
          targets.all(fn(label) {
            tail_call_label_exits_function(label, tail_labels)
          })
        }
        _ => false
      }
    _ => false
  }
}

///|
fn tail_call_rewrite_expr(
  expr : @lib.Expr,
  is_tail : Bool,
  tail_labels : Array[Bool],
  in_local_handler : Bool,
  changed : Array[Bool],
) -> @lib.Expr {
  let @lib.Expr(instrs) = expr
  let rewritten : Array[@lib.Instruction] = []
  for index, instr in instrs {
    let child_is_tail = is_tail && index + 1 == instrs.length()
    let next = match instr {
      @lib.Block(block_type, body) => {
        let labels = tail_labels.copy()
        labels.push(child_is_tail)
        @lib.Instruction::block(
          block_type,
          tail_call_rewrite_expr(
            body, child_is_tail, labels, in_local_handler, changed,
          ),
        )
      }
      @lib.Loop(block_type, body) => {
        let labels = tail_labels.copy()
        labels.push(false)
        @lib.Instruction::loop_(
          block_type,
          tail_call_rewrite_expr(
            body, child_is_tail, labels, in_local_handler, changed,
          ),
        )
      }
      @lib.If(block_type, then_body, else_body) => {
        let labels = tail_labels.copy()
        labels.push(child_is_tail)
        let @lib.Expr(next_then) = tail_call_rewrite_expr(
          @lib.Expr::new(then_body),
          child_is_tail,
          labels,
          in_local_handler,
          changed,
        )
        let next_else = match else_body {
          Some(body) => {
            let @lib.Expr(next_body) = tail_call_rewrite_expr(
              @lib.Expr::new(body),
              child_is_tail,
              labels,
              in_local_handler,
              changed,
            )
            Some(next_body)
          }
          None => None
        }
        @lib.Instruction::if_(block_type, next_then, next_else)
      }
      @lib.Call(target) =>
        if !in_local_handler &&
          tail_call_transfer_after(instrs, index, is_tail, tail_labels) {
          changed[0] = true
          @lib.Instruction::return_call(target)
        } else {
          instr
        }
      @lib.CallIndirect(type_idx, table_idx) =>
        if !in_local_handler &&
          tail_call_transfer_after(instrs, index, is_tail, tail_labels) {
          changed[0] = true
          @lib.Instruction::return_call_indirect(type_idx, table_idx)
        } else {
          instr
        }
      @lib.CallRef(type_idx) =>
        if !in_local_handler &&
          tail_call_transfer_after(instrs, index, is_tail, tail_labels) {
          changed[0] = true
          @lib.Instruction::return_call_ref(type_idx)
        } else {
          instr
        }
      _ => instr
    }
    rewritten.push(next)
  }
  @lib.Expr::new(rewritten)
}

///|
fn tail_call_run_module_pass(mod_ : @lib.Module) -> @lib.Module {
  let @lib.CodeSec(funcs) = match mod_.code_sec {
    Some(section) => section
    None => return mod_
  }
  let changed = [false]
  let next_funcs : Array[@lib.Func] = []
  for func in funcs {
    let @lib.Func(locals, body) = func
    next_funcs.push(
      @lib.Func::new(
        locals,
        tail_call_rewrite_expr(body, true, [], false, changed),
      ),
    )
  }
  if !changed[0] {
    return mod_
  }
  let candidate = mod_.with_code_sec(@lib.CodeSec::new(next_funcs))
  if @validate.validate_module(candidate).is_ok() {
    candidate
  } else {
    mod_
  }
}
