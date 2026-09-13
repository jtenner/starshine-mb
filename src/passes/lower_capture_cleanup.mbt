///|
// Lift captures local values before writes so analysis observes stack order.
// A capture can remain on the stack if the intervening instructions form a
// balanced prefix without consuming that value. Evaluation itself never moves.
fn pass_lower_map_children(
  instr : @lib.Instruction,
  transform : (Array[@lib.Instruction]) -> Array[@lib.Instruction],
) -> @lib.Instruction {
  match instr {
    @lib.Block(bt, @lib.Expr(body)) =>
      @lib.Instruction::block(bt, @lib.Expr::new(transform(body)))
    @lib.Loop(bt, @lib.Expr(body)) =>
      @lib.Instruction::loop_(bt, @lib.Expr::new(transform(body)))
    @lib.If(bt, yes, no) =>
      @lib.Instruction::if_(bt, transform(yes), no.map(transform))
    @lib.TryTable(bt, catches, @lib.Expr(body)) =>
      @lib.Instruction::try_table(bt, catches, @lib.Expr::new(transform(body)))
    @lib.Try(bt, @lib.Expr(body), catches, delegate) =>
      @lib.Instruction::try_(
        bt,
        @lib.Expr::new(transform(body)),
        catches.map(fn(catch_) {
          match catch_ {
            @lib.LegacyCatch(tag, @lib.Expr(body)) =>
              @lib.LegacyCatch::tagged(tag, @lib.Expr::new(transform(body)))
            @lib.LegacyCatchAll(@lib.Expr(body)) =>
              @lib.LegacyCatch::all(@lib.Expr::new(transform(body)))
          }
        }),
        delegate~,
      )
    _ => instr
  }
}

///|
fn pass_lower_count_locals(
  instrs : Array[@lib.Instruction],
  gets : Array[Int],
  writes : Array[Int],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) => gets[index.to_int()] += 1
      @lib.LocalSet(@lib.LocalIdx(index))
      | @lib.LocalTee(@lib.LocalIdx(index)) => writes[index.to_int()] += 1
      _ =>
        ignore(
          pass_lower_map_children(instr, fn(body) {
            pass_lower_count_locals(body, gets, writes)
            body
          }),
        )
    }
  }
}

///|
fn pass_lower_remove_balanced_captures(
  instrs : Array[@lib.Instruction],
  start : Int,
  gets : Array[Int],
  writes : Array[Int],
) -> Array[@lib.Instruction] {
  let out : Array[@lib.Instruction] = []
  let removed = Array::make(instrs.length(), false)
  let mut i = 0
  while i < instrs.length() {
    if removed[i] {
      i += 1
      continue
    }
    match instrs[i] {
      @lib.LocalSet(@lib.LocalIdx(index)) if index.to_int() >= start &&
        gets[index.to_int()] == 1 &&
        writes[index.to_int()] == 1 => {
        let mut height = 0
        let mut read_slot = -1
        // Keep this local cleanup bounded. Longer or structured intervals keep
        // their capture; their producer may throw or observe mutable state.
        for j = i + 1; j < instrs.length() && j <= i + 256; j = j + 1 {
          if removed[j] {
            continue
          }
          if instrs[j] is @lib.LocalGet(@lib.LocalIdx(read)) && read == index {
            if height == 0 {
              read_slot = j
            }
            break
          }
          match instrs[j] {
            @lib.LocalGet(_)
            | @lib.GlobalGet(_)
            | @lib.I32Const(_)
            | @lib.I64Const(_)
            | @lib.F32Const(_)
            | @lib.F64Const(_)
            | @lib.RefNull(_)
            | @lib.RefFunc(_) => height += 1
            @lib.LocalSet(_) => {
              if height == 0 {
                break
              }
              height -= 1
            }
            @lib.LocalTee(_) => if height == 0 { break }
            @lib.Nop => ()
            _ => break
          }
        }
        if read_slot >= 0 {
          gets[index.to_int()] = 0
          writes[index.to_int()] = 0
          removed[read_slot] = true
          i += 1
          continue
        }
      }
      _ => ()
    }
    out.push(
      pass_lower_map_children(instrs[i], fn(body) {
        pass_lower_remove_balanced_captures(body, start, gets, writes)
      }),
    )
    i += 1
  }
  out
}

///|
fn pass_lower_remap_locals(
  instrs : Array[@lib.Instruction],
  indices : Array[Int],
) -> Array[@lib.Instruction] {
  instrs.map(fn(instr) {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) =>
        @lib.Instruction::local_get(
          @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
        )
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        @lib.Instruction::local_set(
          @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
        )
      @lib.LocalTee(@lib.LocalIdx(index)) =>
        @lib.Instruction::local_tee(
          @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
        )
      _ =>
        pass_lower_map_children(instr, fn(body) {
          pass_lower_remap_locals(body, indices)
        })
    }
  })
}

///|
fn pass_lower_compact_captures_with_map(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
) -> (@lib.Func, Array[Int]) {
  let @lib.Func(original_locals, _) = original
  let @lib.Func(locals, @lib.Expr(body)) = func
  if locals.length() <= original_locals.length() {
    return (func, Array::makei(params.length() + locals.length(), fn(i) { i }))
  }
  let count = params.length() + locals.length()
  let start = params.length() + original_locals.length()
  let gets = Array::make(count, 0)
  let writes = Array::make(count, 0)
  pass_lower_count_locals(body, gets, writes)
  let body = pass_lower_remove_balanced_captures(body, start, gets, writes)
  let indices = Array::makei(count, fn(i) { i })
  let retained : Array[@lib.ValType] = []
  for i = 0; i < locals.length(); i = i + 1 {
    let index = params.length() + i
    if index < start || gets[index] > 0 || writes[index] > 0 {
      indices[index] = params.length() + retained.length()
      retained.push(locals.get(i))
    } else {
      indices[index] = -1
    }
  }
  (
    @lib.Func::new(
      @lib.Locals::from_types(retained),
      @lib.Expr::new(pass_lower_remap_locals(body, indices)),
    ),
    indices,
  )
}

///|
fn pass_lower_compact_captures(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
) -> @lib.Func {
  pass_lower_compact_captures_with_map(func, original, params).0
}

///|
fn pass_lower_flatten_branchless_blocks(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
) -> (Array[@lib.Instruction], Bool, Bool) {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let mut branchless = true
  for instr in instrs {
    let mut children_branchless = true
    let instr = pass_lower_map_children(instr, fn(body) {
      let (next, child_changed, child_branchless) = pass_lower_flatten_branchless_blocks(
        body, env,
      )
      changed = changed || child_changed
      children_branchless = children_branchless && child_branchless
      next
    })
    let transfers_control = match instr {
      @lib.Br(_)
      | @lib.BrIf(_)
      | @lib.BrTable(_, _)
      | @lib.BrOnNull(_)
      | @lib.BrOnNonNull(_)
      | @lib.BrOnCast(_, _, _, _)
      | @lib.BrOnCastFail(_, _, _, _)
      | @lib.BrOnCastDescEq(_, _, _)
      | @lib.BrOnCastDescEqFail(_, _, _)
      | @lib.Return
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      | @lib.Unreachable
      | @lib.Try(_, _, _, _)
      | @lib.TryTable(_, _, _)
      | @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Rethrow(_)
      | @lib.Suspend(_)
      | @lib.Resume(_, _)
      | @lib.ResumeThrow(_, _, _)
      | @lib.ResumeThrowRef(_, _)
      | @lib.StackSwitch(_, _) => true
      _ => false
    }
    branchless = branchless && children_branchless && !transfers_control
    match instr {
      @lib.Block(bt, @lib.Expr(body)) if children_branchless =>
        match env.expand_blocktype(bt) {
          Ok((params, _)) if params.is_empty() => {
            // No instruction refers to this or an outer label. With no block
            // parameters, the same ordered producers leave the same results.
            out.append(body)
            changed = true
            continue
          }
          _ => ()
        }
      _ => ()
    }
    out.push(instr)
  }
  (out, changed, branchless)
}

///|
fn pass_lower_cleanup_branchless_blocks(
  func : @lib.Func,
  mod_ : @lib.Module,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let (body, changed, _) = pass_lower_flatten_branchless_blocks(
    body,
    @validate.Env::new().with_module(mod_),
  )
  if changed {
    (@lib.Func::new(locals, @lib.Expr::new(body)), true)
  } else {
    (func, false)
  }
}
