///|
fn cl_tee_control_cleanup_reference(
  rewritten_instrs : Array[@lib.Instruction],
  original_instrs : Array[@lib.Instruction],
  effective : Array[Bool],
  action_cursor : Array[Int],
  control_visits? : Array[Int]? = None,
) -> Bool {
  let out : Array[@lib.Instruction] = []
  let mut changed = false
  let reachable_len = cl_reachable_prefix_len(
    original_instrs,
    instruction_visits=control_visits,
  )
  for idx = 0; idx < rewritten_instrs.length(); idx = idx + 1 {
    // Collection and rewriting assign action ordinals only to reachable code.
    if idx >= reachable_len {
      out.push(rewritten_instrs[idx])
      continue
    }
    let original = original_instrs[idx]
    let mut rewritten = rewritten_instrs[idx]
    match original {
      @lib.Block(_, @lib.Expr(original_body)) =>
        match rewritten {
          @lib.Block(block_type, @lib.Expr(body)) => {
            changed = cl_tee_control_cleanup_reference(
                body,
                original_body,
                effective,
                action_cursor,
                control_visits~,
              ) ||
              changed
            rewritten = @lib.Instruction::block(
              block_type,
              @lib.Expr::new(body),
            )
          }
          _ => ()
        }
      @lib.Loop(_, @lib.Expr(original_body)) =>
        match rewritten {
          @lib.Loop(block_type, @lib.Expr(body)) => {
            changed = cl_tee_control_cleanup_reference(
                body,
                original_body,
                effective,
                action_cursor,
                control_visits~,
              ) ||
              changed
            rewritten = @lib.Instruction::loop_(
              block_type,
              @lib.Expr::new(body),
            )
          }
          _ => ()
        }
      @lib.If(_, original_then, original_else) =>
        match rewritten {
          @lib.If(block_type, then_body, else_body) => {
            changed = cl_tee_control_cleanup_reference(
                then_body,
                original_then,
                effective,
                action_cursor,
                control_visits~,
              ) ||
              changed
            match (else_body, original_else) {
              (Some(body), Some(original_body)) =>
                changed = cl_tee_control_cleanup_reference(
                    body,
                    original_body,
                    effective,
                    action_cursor,
                    control_visits~,
                  ) ||
                  changed
              _ => ()
            }
            rewritten = @lib.Instruction::if_(block_type, then_body, else_body)
          }
          _ => ()
        }
      @lib.TryTable(_, _, @lib.Expr(original_body)) =>
        match rewritten {
          @lib.TryTable(block_type, catches, @lib.Expr(body)) => {
            changed = cl_tee_control_cleanup_reference(
                body,
                original_body,
                effective,
                action_cursor,
                control_visits~,
              ) ||
              changed
            rewritten = @lib.Instruction::try_table(
              block_type,
              catches,
              @lib.Expr::new(body),
            )
          }
          _ => ()
        }
      @lib.LocalGet(_) | @lib.LocalSet(_) => action_cursor[0] += 1
      @lib.LocalTee(original_local_idx) => {
        let action_idx = action_cursor[0]
        action_cursor[0] += 1
        if action_idx >= 0 &&
          action_idx < effective.length() &&
          !effective[action_idx] {
          if cl_suffix_reads_local_before_overwrite(
              original_instrs,
              idx + 1,
              original_local_idx,
            ) {
            ()
          } else {
            changed = true
            continue
          }
        }
      }
      _ => ()
    }
    out.push(rewritten)
  }
  if changed {
    rewritten_instrs.clear()
    rewritten_instrs.append(out)
  }
  changed
}

///|
fn cl_tee_control_bench(it : @bench.T, depth : Int, reference : Bool) -> Unit {
  let input = cl_tee_control_fixture(depth)
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let original_bytes = @binary.encode_module(input).unwrap()
  let run = fn(old) {
    let cursor = [0]
    if old {
      cl_tee_control_cleanup_reference(body, body, [true], cursor)
    } else {
      cl_remove_ineffective_tees(body, body, [true], cursor)
    }
  }
  if run(true) ||
    run(false) ||
    @binary.encode_module(input).unwrap() != original_bytes {
    abort("tee cleanup unchanged fixture must retain its input for reuse")
  }
  it.bench(fn() { it.keep(run(reference)) })
}

///|
test "bench CL tee control depth=0 reference" (it : @bench.T) {
  cl_tee_control_bench(it, 0, true)
}

///|
test "bench CL tee control depth=0 indexed" (it : @bench.T) {
  cl_tee_control_bench(it, 0, false)
}

///|
test "bench CL tee control depth=8 reference" (it : @bench.T) {
  cl_tee_control_bench(it, 8, true)
}

///|
test "bench CL tee control depth=8 indexed" (it : @bench.T) {
  cl_tee_control_bench(it, 8, false)
}

///|
test "bench CL tee control depth=64 reference" (it : @bench.T) {
  cl_tee_control_bench(it, 64, true)
}

///|
test "bench CL tee control depth=64 indexed" (it : @bench.T) {
  cl_tee_control_bench(it, 64, false)
}

///|
test "bench CL tee control depth=256 reference" (it : @bench.T) {
  cl_tee_control_bench(it, 256, true)
}

///|
test "bench CL tee control depth=256 indexed" (it : @bench.T) {
  cl_tee_control_bench(it, 256, false)
}

///|
fn cl_union_live(lhs : Array[Bool], rhs : Array[Bool]) -> Array[Bool] {
  let out = lhs.copy()
  for idx = 0; idx < out.length(); idx = idx + 1 {
    out[idx] = out[idx] || rhs[idx]
  }
  out
}

///|
fn cl_control_liveness_reference(
  instrs : Array[@lib.Instruction],
  actions : Array[CLAction],
  effective : Array[Bool],
  write_live_hazards : CLBitMatrix,
  visited_actions : Array[Int],
  live_after : Array[Bool],
  label_lives : Array[Array[Bool]],
  action_cursor : Array[Int],
  exception_live? : Array[Bool] = [],
) -> Array[Bool] {
  let live = live_after.copy()
  let reachable_len = cl_reachable_prefix_len(instrs)
  let mut idx = instrs.length() - 1
  while idx >= 0 {
    if idx >= reachable_len {
      idx -= 1
      continue
    }
    match instrs[idx] {
      @lib.Block(_, @lib.Expr(body)) => {
        let body_live = cl_control_liveness_reference(
          body,
          actions,
          effective,
          write_live_hazards,
          visited_actions,
          live,
          cl_push_label_live(live, label_lives),
          action_cursor,
          exception_live~,
        )
        cl_replace_live(live, body_live)
      }
      @lib.If(_, then_body, else_body) => {
        let live_after_if = live.copy()
        let child_label_lives = cl_push_label_live(live_after_if, label_lives)
        let else_live = match else_body {
          Some(body) =>
            cl_control_liveness_reference(
              body,
              actions,
              effective,
              write_live_hazards,
              visited_actions,
              live_after_if.copy(),
              child_label_lives,
              action_cursor,
              exception_live~,
            )
          None => live_after_if.copy()
        }
        let then_live = cl_control_liveness_reference(
          then_body,
          actions,
          effective,
          write_live_hazards,
          visited_actions,
          live_after_if,
          child_label_lives,
          action_cursor,
          exception_live~,
        )
        let merged_live = cl_union_live(then_live, else_live)
        cl_replace_live(live, merged_live)
      }
      @lib.Loop(_, @lib.Expr(body)) => {
        let body_live = cl_control_liveness_reference(
          body,
          actions,
          effective,
          write_live_hazards,
          visited_actions,
          live,
          cl_push_label_live(live, label_lives),
          action_cursor,
          exception_live~,
        )
        cl_replace_live(live, body_live)
      }
      @lib.TryTable(_, catches, @lib.Expr(body)) => {
        // Catches target enclosing labels, without the try_table body label.
        let caught_live = exception_live.copy()
        while caught_live.length() < live.length() {
          caught_live.push(false)
        }
        for catch_ in catches {
          let label = match catch_ {
            @lib.Catch(_, label)
            | @lib.CatchRef(_, label)
            | @lib.CatchAll(label)
            | @lib.CatchAllRef(label) => label
          }
          cl_union_live_in_place(
            caught_live,
            cl_live_for_label(label_lives, label, live.length()),
          )
        }
        let body_live = cl_control_liveness_reference(
          body,
          actions,
          effective,
          write_live_hazards,
          visited_actions,
          live,
          cl_push_label_live(live, label_lives),
          action_cursor,
          exception_live=caught_live,
        )
        cl_replace_live(live, body_live)
      }
      @lib.LocalGet(_) | @lib.LocalSet(_) | @lib.LocalTee(_) => {
        let action_idx = action_cursor[0]
        if action_idx >= 0 && action_idx < actions.length() {
          visited_actions[0] += 1
          let action = actions[action_idx]
          match action.kind {
            CLActionKind::Get => live[action.local_idx] = true
            CLActionKind::Set | CLActionKind::Tee => {
              if live[action.local_idx] {
                effective[action_idx] = true
                let copied_dest = match action.source {
                  CLValueSource::Local(local_idx) => local_idx
                  _ => -1
                }
                for other = 0; other < live.length(); other = other + 1 {
                  if other != action.local_idx &&
                    other != copied_dest &&
                    live[other] {
                    cl_bit_matrix_set_symmetric(
                      write_live_hazards,
                      action.local_idx,
                      other,
                      true,
                    )
                  }
                }
              }
              live[action.local_idx] = false
            }
          }
        }
        action_cursor[0] -= 1
      }
      @lib.Br(label_idx) =>
        cl_replace_live(
          live,
          cl_live_for_label(label_lives, label_idx, live.length()),
        )
      @lib.BrIf(label_idx)
      | @lib.BrOnNull(label_idx)
      | @lib.BrOnNonNull(label_idx)
      | @lib.BrOnCast(label_idx, _, _, _)
      | @lib.BrOnCastFail(label_idx, _, _, _)
      | @lib.BrOnCastDescEq(label_idx, _, _)
      | @lib.BrOnCastDescEqFail(label_idx, _, _) =>
        cl_union_live_in_place(
          live,
          cl_live_for_label(label_lives, label_idx, live.length()),
        )
      @lib.BrTable(labels, default_label) =>
        cl_replace_live(
          live,
          cl_live_for_br_table(
            label_lives,
            labels,
            default_label,
            live.length(),
          ),
        )
      @lib.Throw(_)
      | @lib.ThrowRef
      | @lib.Rethrow(_)
      | @lib.ReturnCall(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_) => cl_replace_live(live, exception_live)
      @lib.Call(_)
      | @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.Suspend(_)
      | @lib.StackSwitch(_, _) => cl_union_live_in_place(live, exception_live)
      @lib.Resume(_, handlers)
      | @lib.ResumeThrow(_, _, handlers)
      | @lib.ResumeThrowRef(_, handlers) => {
        cl_union_live_in_place(live, exception_live)
        cl_union_resume_handler_lives(live, label_lives, handlers)
      }
      instr => if cl_instr_is_terminal(instr) { cl_clear_live(live) }
    }
    idx -= 1
  }
  live
}

///|
fn cl_control_liveness_bench(
  it : @bench.T,
  depth : Int,
  reference : Bool,
) -> Unit {
  let input = cl_tee_control_fixture(depth)
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let actions : Array[CLAction] = []
  cl_collect_instrs(body, actions, 1)
  let run = fn(old) {
    let effective = Array::make(actions.length(), false)
    let hazards = CLBitMatrix::new(1)
    let cursor = [actions.length() - 1]
    let visited = [0]
    if old {
      cl_control_liveness_reference(
        body,
        actions,
        effective,
        hazards,
        visited,
        [false],
        [],
        cursor,
      )
    } else {
      cl_mark_structured_liveness_backward(
        body,
        actions,
        effective,
        hazards,
        visited,
        [false],
        [],
        cursor,
      )
    }
  }
  if run(true) != run(false) {
    abort("indexed liveness must match the retained complete proof")
  }
  it.bench(fn() { it.keep(run(reference)) })
}

///|
test "bench CL backward control depth=8 reference" (it : @bench.T) {
  cl_control_liveness_bench(it, 8, true)
}

///|
test "bench CL backward control depth=8 indexed" (it : @bench.T) {
  cl_control_liveness_bench(it, 8, false)
}

///|
test "bench CL backward control depth=64 reference" (it : @bench.T) {
  cl_control_liveness_bench(it, 64, true)
}

///|
test "bench CL backward control depth=64 indexed" (it : @bench.T) {
  cl_control_liveness_bench(it, 64, false)
}

///|
test "bench CL backward control depth=256 reference" (it : @bench.T) {
  cl_control_liveness_bench(it, 256, true)
}

///|
test "bench CL backward control depth=256 indexed" (it : @bench.T) {
  cl_control_liveness_bench(it, 256, false)
}
