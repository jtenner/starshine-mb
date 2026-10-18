// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

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
  gets : Array[Int32],
  writes : Array[Int32],
) -> Unit {
  for instr in instrs {
    match instr {
      @lib.LocalGet(@lib.LocalIdx(index)) => gets[index.to_int()] += 1
      @lib.LocalSet(@lib.LocalIdx(index))
      | @lib.LocalTee(@lib.LocalIdx(index)) => writes[index.to_int()] += 1
      _ => pass_lower_count_child_locals(instr, gets, writes)
    }
  }
}

///|
fn pass_lower_count_child_locals(
  instr : @lib.Instruction,
  gets : Array[Int32],
  writes : Array[Int32],
) -> Unit {
  match instr {
    @lib.Block(_, @lib.Expr(body))
    | @lib.Loop(_, @lib.Expr(body))
    | @lib.TryTable(_, _, @lib.Expr(body)) =>
      pass_lower_count_locals(body, gets, writes)
    @lib.If(_, yes, no) => {
      pass_lower_count_locals(yes, gets, writes)
      match no {
        Some(body) => pass_lower_count_locals(body, gets, writes)
        None => ()
      }
    }
    @lib.Try(_, @lib.Expr(body), catches, _) => {
      pass_lower_count_locals(body, gets, writes)
      for catch_ in catches {
        let body = match catch_ {
          @lib.LegacyCatch(_, @lib.Expr(body))
          | @lib.LegacyCatchAll(@lib.Expr(body)) => body
        }
        pass_lower_count_locals(body, gets, writes)
      }
    }
    _ => ()
  }
}

///|
fn pass_lower_remove_balanced_captures(
  instrs : Array[@lib.Instruction],
  start : Int32,
  gets : Array[Int32],
  writes : Array[Int32],
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
) -> Array[@lib.Instruction] {
  pass_lower_remove_balanced_captures_impl(
    instrs, start, gets, writes, false, stack_effects,
  )
}

///|
fn pass_lower_remove_balanced_captures_impl(
  instrs : Array[@lib.Instruction],
  start : Int32,
  gets : Array[Int32],
  writes : Array[Int32],
  borrow_unchanged : Bool,
  stack_effects : ((@lib.Instruction) -> (Int32, Int32)?)?,
) -> Array[@lib.Instruction] {
  let mut out : Array[@lib.Instruction]? = if borrow_unchanged {
    None
  } else {
    Some([])
  }
  let removed = Array::make(instrs.length(), false)
  let visit_body = fn(body) {
    pass_lower_remove_balanced_captures_impl(
      body, start, gets, writes, borrow_unchanged, stack_effects,
    )
  }
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
          match stack_effects {
            Some(query) => {
              match query(instrs[j]) {
                Some((inputs, outputs)) if inputs >= 0 &&
                  outputs >= 0 &&
                  inputs <= height => height = height - inputs + outputs
                _ => break
              }
              continue
            }
            None => ()
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
            @lib.Drop => {
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
          if out is None {
            let prefix = []
            for slot in 0..<i {
              prefix.push(instrs[slot])
            }
            out = Some(prefix)
          }
          gets[index.to_int()] = 0
          writes[index.to_int()] = 0
          removed[read_slot] = true
          i += 1
          continue
        }
      }
      _ => ()
    }
    let next = if borrow_unchanged {
      pass_lower_map_children_borrow_unchanged(instrs[i], visit_body)
    } else {
      pass_lower_map_children(instrs[i], visit_body)
    }
    match out {
      Some(out) => out.push(next)
      None =>
        if !physical_equal(next, instrs[i]) {
          let prefix = []
          for slot in 0..<i {
            prefix.push(instrs[slot])
          }
          prefix.push(next)
          out = Some(prefix)
        }
    }
    i += 1
  }
  match out {
    Some(out) => out
    None => instrs
  }
}

///|
fn pass_lower_remap_locals(
  instrs : Array[@lib.Instruction],
  indices : Array[Int32],
) -> Array[@lib.Instruction] {
  let visit_body = fn(body) { pass_lower_remap_locals(body, indices) }
  let out = Array::new(capacity=instrs.length())
  for instr in instrs {
    match instr {
      @lib.LocalTee(@lib.LocalIdx(index)) if indices[index.to_int()] < 0 =>
        continue
      _ => ()
    }
    out.push(
      match instr {
        @lib.LocalGet(@lib.LocalIdx(index)) =>
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
          )
        @lib.LocalSet(@lib.LocalIdx(index)) =>
          if indices[index.to_int()] < 0 {
            @lib.Instruction::drop()
          } else {
            @lib.Instruction::local_set(
              @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
            )
          }
        @lib.LocalTee(@lib.LocalIdx(index)) =>
          @lib.Instruction::local_tee(
            @lib.LocalIdx::new(indices[index.to_int()].reinterpret_as_uint()),
          )
        @lib.Select(Some(types)) =>
          @lib.Instruction::select(types=Some(types.copy()))
        @lib.BrTable(targets, fallback) =>
          @lib.Instruction::br_table(targets.copy(), fallback)
        @lib.TryTable(bt, catches, @lib.Expr(body)) =>
          @lib.Instruction::try_table(
            bt,
            catches.copy(),
            @lib.Expr::new(visit_body(body)),
          )
        _ => pass_lower_map_children(instr, visit_body)
      },
    )
  }
  out
}

///|
fn pass_lower_compact_captures_with_map(
  func : @lib.Func,
  original : @lib.Func,
  params : Array[@lib.ValType],
  stack_effects~ : ((@lib.Instruction) -> (Int32, Int32)?)? = None,
  propagate_parameter_aliases~ : Bool = false,
  reorder_body_locals~ : Bool = false,
  local_name_sec~ : @lib.NameSec? = None,
  function_abs~ : Int32 = -1,
  local_counts~ : (Array[Int32], Array[Int32])? = None,
) -> (@lib.Func, Array[Int32]) {
  let @lib.Func(original_locals, _) = original
  let @lib.Func(locals, @lib.Expr(body)) = func
  if locals.length() <= original_locals.length() {
    return (func, Array::makei(params.length() + locals.length(), fn(i) { i }))
  }
  let count = params.length() + locals.length()
  let start = params.length() + original_locals.length()
  // The optional census belongs to this exact body/local snapshot. This
  // compaction consumes it: capture removal and alias propagation update it.
  let (gets, writes) = match local_counts {
    Some(counts) => counts
    None => {
      let gets = Array::make(count, 0)
      let writes = Array::make(count, 0)
      pass_lower_count_locals(body, gets, writes)
      (gets, writes)
    }
  }
  let mut has_capture = !propagate_parameter_aliases
  let mut has_unused = false
  let mut has_single_write = false
  // The plain lowerer keeps its existing path. Optimizing cleanup can also
  // remove aliases, so prove whether either cleanup family has work here.
  if propagate_parameter_aliases {
    for local_id in start..<count {
      let reads = gets[local_id]
      let write_count = writes[local_id]
      if reads == 1 && write_count == 1 {
        has_capture = true
        break
      }
      has_single_write = has_single_write || write_count == 1
      has_unused = has_unused || reads == 0
    }
  }
  if !has_capture &&
    !has_unused &&
    (
      !has_single_write ||
      !dae2_has_parameter_alias(body, start, writes, stack_effects~)
    ) {
    // Capture removal needs single-read, single-write locals. With
    // no such pair, no dead declaration and no alias, the exact map is identity.
    let runs = locals.runs
    let mut normalize = false
    for index in 0..<runs.length() {
      if runs[index].count == 0U ||
        (index > 0 && runs[index - 1].vt == runs[index].vt) {
        normalize = true
        break
      }
    }
    let func = if normalize {
      @lib.Func::new(@lib.Locals::new(runs), @lib.Expr::new(body))
    } else {
      func
    }
    return (func, Array::makei(count, fn(i) { i }))
  }
  // Keep the existing leaf plan first: an earlier effect-spanning capture can
  // otherwise block several smaller overlapping captures. The second pass
  // only deletes additional pairs from that already valid stack plan.
  let body = if has_capture {
    pass_lower_remove_balanced_captures_impl(
      body,
      start,
      gets,
      writes,
      true,
      None,
    )
  } else {
    body
  }
  let body = match stack_effects {
    Some(_) if has_capture => {
      let mut remaining = false
      for local_id in start..<count {
        if gets[local_id] == 1 && writes[local_id] == 1 {
          remaining = true
          break
        }
      }
      if remaining {
        pass_lower_remove_balanced_captures_impl(
          body, start, gets, writes, true, stack_effects,
        )
      } else {
        body
      }
    }
    _ => body
  }
  // Preserve the complete legacy capture plan before alias propagation.
  // Moving even a pure parameter read can otherwise obstruct a smaller stack
  // plan chosen for an overlapping computed value.
  let (body, unread_aliases) = if propagate_parameter_aliases &&
    (!has_unused || gets.any(fn(reads) { reads > 0 })) {
    dae2_cleanup_parameter_aliases(body, start, gets, writes, stack_effects~)
  } else {
    (body, None)
  }
  if propagate_parameter_aliases {
    // The complete census and alias demand transfers include every nested and
    // legacy handler read. Retire only body-local writes with no remaining read;
    // remapping preserves the produced value (tee) or consumes it (set/drop).
    for local_id in start..<count {
      if gets[local_id] == 0 {
        writes[local_id] = 0
      }
    }
  }
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
  if reorder_body_locals && start == params.length() {
    ignore(
      dae2_order_compacted_local_indices(
        indices,
        gets,
        writes,
        params.length(),
        retained,
        local_name_sec,
        function_abs,
      ),
    )
  }
  (
    @lib.Func::new(
      @lib.Locals::from_types(retained),
      @lib.Expr::new(
        match unread_aliases {
          Some(aliases) => aliases.remap(body, indices)
          None => pass_lower_remap_locals(body, indices)
        },
      ),
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
fn pass_lower_instr_transfers_control(instr : @lib.Instruction) -> Bool {
  match instr {
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
}

///|
fn pass_lower_flatten_branchless_blocks_into(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  out : Array[@lib.Instruction],
  label_keep~ : Array[Bool]? = None,
  flatten_parameter_blocks~ : Bool = false,
  flatten_scalar_identity_blocks~ : Bool = false,
) -> (Bool, Bool) {
  let mut changed = false
  let mut branchless = true
  let mut children_branchless = true
  let visit_body = fn(body) {
    let (next, child_changed, child_branchless) = pass_lower_flatten_branchless_blocks(
      body,
      env,
      label_keep~,
      flatten_parameter_blocks~,
      flatten_scalar_identity_blocks~,
    )
    changed = changed || child_changed
    children_branchless = children_branchless && child_branchless
    next
  }
  for instr in instrs {
    let label_slot = match (label_keep, instr) {
      (
        Some(keep),
        @lib.Block(_, _)
        | @lib.Loop(_, _)
        | @lib.If(_, _, _)
        | @lib.TryTable(_, _, _)
        | @lib.Try(_, _, _, _),
      ) => {
        let slot = keep.length()
        keep.push(true)
        Some(slot)
      }
      _ => None
    }
    match instr {
      @lib.Block(block_type, @lib.Expr(body)) => {
        let body_start = out.length()
        let (body_changed, body_branchless) = pass_lower_flatten_branchless_blocks_into(
          body,
          env,
          out,
          label_keep~,
          flatten_parameter_blocks~,
          flatten_scalar_identity_blocks~,
        )
        changed = changed || body_changed
        branchless = branchless && body_branchless
        let mut flatten = false
        if body_branchless {
          match env.expand_blocktype(block_type) {
            // With no control transfers, the validated body consumes the same
            // entry values and leaves the same results without its wrapper.
            Ok((params, results)) if flatten_parameter_blocks ||
              params.is_empty() ||
              (
                flatten_scalar_identity_blocks &&
                params.length() == 1 &&
                results.length() == 1 &&
                params[0] == results[0] &&
                body.all(fn(instr) { instr is @lib.Nop })
              ) => flatten = true
            _ => ()
          }
        }
        if flatten {
          // The body is already in the parent's output; no growing array copy.
          match (label_keep, label_slot) {
            (Some(keep), Some(slot)) => keep[slot] = false
            _ => ()
          }
          changed = true
          continue
        }
        let next_body : Array[@lib.Instruction] = []
        if body_changed {
          for idx = body_start; idx < out.length(); idx = idx + 1 {
            next_body.push(out[idx])
          }
        }
        while out.length() > body_start {
          ignore(out.pop())
        }
        out.push(
          if body_changed {
            @lib.Instruction::block(block_type, @lib.Expr::new(next_body))
          } else {
            instr
          },
        )
        continue
      }
      _ => ()
    }
    children_branchless = true
    let instr = pass_lower_map_children(instr, visit_body)
    let transfers_control = pass_lower_instruction_transfers_control(instr)
    branchless = branchless && children_branchless && !transfers_control
    out.push(instr)
  }
  (changed, branchless)
}

///|
fn pass_lower_flatten_branchless_blocks(
  instrs : Array[@lib.Instruction],
  env : @validate.Env,
  label_keep~ : Array[Bool]? = None,
  flatten_parameter_blocks~ : Bool = false,
  flatten_scalar_identity_blocks~ : Bool = false,
) -> (Array[@lib.Instruction], Bool, Bool) {
  let out : Array[@lib.Instruction] = []
  let (changed, branchless) = pass_lower_flatten_branchless_blocks_into(
    instrs,
    env,
    out,
    label_keep~,
    flatten_parameter_blocks~,
    flatten_scalar_identity_blocks~,
  )
  (out, changed, branchless)
}

///|
fn pass_lower_cleanup_branchless_blocks(
  func : @lib.Func,
  mod_ : @lib.Module,
  module_env~ : @validate.Env? = None,
  flatten_parameter_blocks~ : Bool = false,
  flatten_scalar_identity_blocks~ : Bool = false,
  rewrite_work~ : Array[Int32]? = None,
) -> (@lib.Func, Bool) {
  let @lib.Func(locals, @lib.Expr(body)) = func
  let has_candidate = if body.length() == 1 ||
    (body.length() == 2 && pass_lower_branchless_leaf(body[1])) {
    match body[0] {
      @lib.Block(@lib.VoidBlockType, @lib.Expr(child)) => {
        let summary = pass_lower_branchless_summary(child)
        if summary.branchless && !summary.has_children {
          // A void header needs no module lookup. Leaf instructions have no
          // nested mutable body arrays that the old worker would rebuild.
          // Copy into a fresh root array to preserve its output ownership.
          let next = Array::new(capacity=child.length() + body.length() - 1)
          for instr in child {
            next.push(instr)
          }
          if body.length() == 2 {
            next.push(body[1])
          }
          return (@lib.Func::new(locals, @lib.Expr::new(next)), true)
        }
        summary.has_candidate || summary.branchless
      }
      _ => pass_lower_branchless_summary(body).has_candidate
    }
  } else {
    pass_lower_branchless_summary(body).has_candidate
  }
  if !has_candidate {
    return (func, false)
  }
  let env = match module_env {
    Some(env) => env
    None => @validate.Env::new().with_module(mod_)
  }
  match rewrite_work {
    Some(work) => work[0] += 1
    None => ()
  }
  let (body, changed, _) = pass_lower_flatten_branchless_blocks(
    body,
    env,
    flatten_parameter_blocks~,
    flatten_scalar_identity_blocks~,
  )
  if changed {
    (@lib.Func::new(locals, @lib.Expr::new(body)), true)
  } else {
    (func, false)
  }
}

///|
test "lower cleanup flattens opted in mixed typed blocks and preserves branch labels" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i64) (result i32) local.get 0 local.get 1 block (param i32 i64) (result i32) drop i32.const 1 i32.add end))",
  )
  let expected = pass_test_module_from_wat(
    "(module (func (param i32 i64) (result i32) local.get 0 local.get 1 drop i32.const 1 i32.add))",
  )
  let func = input.code_sec.unwrap().0[0]
  let (retained, changed) = pass_lower_cleanup_branchless_blocks(func, input)
  assert_eq(retained, func)
  assert_true(!changed)
  let (flattened, changed) = pass_lower_cleanup_branchless_blocks(
    func,
    input,
    flatten_parameter_blocks=true,
  )
  assert_true(changed)
  assert_eq(flattened, expected.code_sec.unwrap().0[0])
  @validate.validate_module(input.with_code_sec(@lib.CodeSec::new([flattened]))).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = func
  let keep : Array[Bool] = []
  ignore(
    pass_lower_flatten_branchless_blocks(
      body,
      @validate.Env::new().with_module(input),
      label_keep=Some(keep),
      flatten_parameter_blocks=true,
    ),
  )
  assert_eq(keep, [false])
  let branched = pass_test_module_from_wat(
    "(module (func (param i32 i64) (result i32) local.get 0 local.get 1 block (param i32 i64) (result i32) drop i32.const 1 i32.add br 0 end))",
  )
  let func = branched.code_sec.unwrap().0[0]
  let (retained, changed) = pass_lower_cleanup_branchless_blocks(
    func,
    branched,
    flatten_parameter_blocks=true,
  )
  assert_eq(retained, func)
  assert_true(!changed)
  @validate.validate_module(
    branched.with_code_sec(@lib.CodeSec::new([retained])),
  ).unwrap()
}

///|
test "DAE2 cleanup census includes parameter aliases and nested accesses" {
  for
    body in [
      "local.get 0 local.set 1 local.get 1 drop local.get 1 drop", "block local.get 0 local.set 1 local.get 1 drop local.get 1 drop end",
      "try_table local.get 0 local.set 1 local.get 1 drop local.get 1 drop end",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func (param i32) (local i32) \{body}))",
    )
    let func = input.code_sec.unwrap().0[0]
    let admission = dae2_cleanup_admit_func(
      func,
      [@lib.ValType::i32()],
      @ir.hot_module_context_from_module(input),
    )
    assert_true(admission.may_change())
    assert_false(admission.has_forwarding())
    let (gets, writes) = admission.local_counts().unwrap()
    assert_eq(gets, [1, 2])
    assert_eq(writes, [0, 1])
    let output = dae2_cleanup_captures(input)
    @validate.validate_module(output).unwrap()
    let @lib.Func(locals, _) = output.code_sec.unwrap().0[0]
    assert_eq(locals.length(), 0)
  }
}
