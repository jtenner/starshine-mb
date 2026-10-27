// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// Build the solved call projection once. A nonnegative suffix count means all
// retained arguments precede all discarded arguments. Results are an indivisible
// boundary in DAE2: either every original result remains, or every one is gone.
priv struct Dae2StackSuffixPlan {
  suffixes : Array[Int32]
  removed_results : Array[Int32]
}

///|
// Optional rewrite metadata does not enlarge every dependency function record,
// including type-family records that can never own a raw body.
priv struct Dae2StackSuffixState {
  admissions : Array[Int32]
  original_writes : Array[Array[(Int32, Int32)]?]
  context : @ir.HotModuleContext?
}

///|
fn Dae2StackSuffixState::new(
  count : Int32,
  context? : @ir.HotModuleContext,
) -> Dae2StackSuffixState {
  {
    admissions: Array::make(count, 0),
    original_writes: Array::make(count, None),
    context,
  }
}

///|
// A no-result loop keeps the same entry stack and branch payload types. The
// caller separately proves that none of its referenced type families changes.
fn dae2_stack_suffix_indexed_loop_has_no_results(
  context : @ir.HotModuleContext?,
  index : @lib.TypeIdx,
) -> Bool {
  match context {
    Some(context) =>
      @ir.hot_module_resolve_type_func_type(context, index)
      is Some(@lib.FuncType(_, []))
    None => false
  }
}

///|
priv struct Dae2StackSuffixWriteDemand {
  base : Int32
  original_writes : Array[(Int32, Int32)]?
  graph : Dae2Graph
  mut cursor : Int32
}

///|
fn Dae2StackSuffixWriteDemand::new(
  info : Dae2Function,
  graph : Dae2Graph,
  original_writes : Array[(Int32, Int32)]?,
) -> Dae2StackSuffixWriteDemand {
  // HOT provenance uses relative node IDs; raw conditional provenance records
  // absolute dependency locations. Both rows follow original source-write order.
  match original_writes {
    Some(_) =>
      { base: info.node_location_base, original_writes, graph, cursor: 0, }
    None =>
      { base: 0, original_writes: info.raw_write_locations, graph, cursor: 0, }
  }
}

///|
fn Dae2StackSuffixWriteDemand::allows(
  self : Dae2StackSuffixWriteDemand,
  local : Int32,
  read : Bool,
) -> Bool {
  match self.original_writes {
    Some(writes) => {
      if self.cursor >= writes.length() || writes[self.cursor].0 != local {
        return false
      }
      let node = writes[self.cursor].1
      self.cursor += 1
      // A global read mask alone cannot prove a particular write reaches a
      // demanded get. Decline overwritten stores and stack-polymorphic writes.
      !read || (node >= 0 && self.graph.used[self.base + node])
    }
    None => !read
  }
}

///|
fn Dae2StackSuffixPlan::new(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
) -> Dae2StackSuffixPlan {
  let suffixes = []
  let removed_results = []
  for info in infos {
    let mut suffix = 0
    let mut prefix = true
    for param in info.param_locations {
      if graph.used[param] {
        if suffix > 0 {
          prefix = false
        }
      } else {
        suffix += 1
      }
    }
    suffixes.push(if prefix { suffix } else { -1 })
    removed_results.push(
      if graph.used[info.result_location] {
        0
      } else {
        info.results.length()
      },
    )
  }
  { suffixes, removed_results, }
}

///|
fn dae2_stack_suffix_discardable_leaf(instr : @lib.Instruction) -> Bool {
  match instr {
    @lib.LocalGet(_)
    | @lib.GlobalGet(_)
    | @lib.I32Const(_)
    | @lib.I64Const(_)
    | @lib.F32Const(_)
    | @lib.F64Const(_)
    | @lib.V128Const(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _)
    | @lib.RefNull(_)
    | @lib.RefFunc(_)
    | @lib.StringConst(_) => true
    _ => false
  }
}

///|
fn dae2_stack_suffix_mark_reads(
  instrs : Array[@lib.Instruction],
  reads : Array[Bool],
  plan : Dae2StackSuffixPlan,
) -> Unit {
  let mut suffix_call = dae2_stack_suffix_next_call(instrs, plan, 0)
  for position in 0..<instrs.length() {
    if suffix_call >= 0 &&
      position < suffix_call &&
      position >=
      suffix_call - plan.suffixes[dae2_stack_suffix_callee(instrs[suffix_call])] {
      continue
    }
    if position == suffix_call {
      suffix_call = dae2_stack_suffix_next_call(instrs, plan, position + 1)
    }
    let instr = instrs[position]
    match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) => reads[raw.to_int()] = true
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        dae2_stack_suffix_mark_reads(body, reads, plan)
      @lib.If(_, yes, no) => {
        dae2_stack_suffix_mark_reads(yes, reads, plan)
        match no {
          Some(body) => dae2_stack_suffix_mark_reads(body, reads, plan)
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        dae2_stack_suffix_mark_reads(body, reads, plan)
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          dae2_stack_suffix_mark_reads(body, reads, plan)
        }
      }
      _ => ()
    }
  }
}

///|
fn dae2_stack_suffix_callee(instr : @lib.Instruction) -> Int32 {
  match instr {
    @lib.Call(@lib.FuncIdx(raw)) | @lib.ReturnCall(@lib.FuncIdx(raw)) =>
      raw.to_int()
    _ => -1
  }
}

///|
// A monotonic lookahead avoids either an instruction-sized marker array or
// rescanning a long argument list independently for every local.get.
fn dae2_stack_suffix_next_call(
  instrs : Array[@lib.Instruction],
  plan : Dae2StackSuffixPlan,
  start : Int32,
) -> Int32 {
  for position in start..<instrs.length() {
    let callee = dae2_stack_suffix_callee(instrs[position])
    if callee >= 0 &&
      callee < plan.suffixes.length() &&
      plan.suffixes[callee] > 0 {
      return position
    }
  }
  -1
}

///|
// General pure-expression deletion can also make an earlier local unread.
// Keep that dependency projection in HOT. Here a discarded scalar producer
// either has no body-local dependency or must execute with its inputs intact.
fn dae2_stack_suffix_keeps_discard_cleanup(
  instr : @lib.Instruction,
  params : Int32,
) -> Bool {
  match instr {
    @lib.LocalGet(@lib.LocalIdx(raw)) => raw.to_int() < params
    @lib.Call(_) | @lib.LocalTee(_) => true
    _ =>
      dae2_stack_suffix_discardable_leaf(instr) ||
      dae2_raw_observed_producer_arity(instr, None) >= 0
  }
}

///|
fn dae2_stack_suffix_discard_qualifies(
  instrs : Array[@lib.Instruction],
  position : Int32,
  reads : Array[Bool],
  params : Int32,
) -> Bool {
  let mut producer = position - 1
  while producer >= 0 {
    match instrs[producer] {
      @lib.LocalTee(@lib.LocalIdx(local)) if !reads[local.to_int()] =>
        producer -= 1
      _ => break
    }
  }
  producer >= 0 &&
  dae2_stack_suffix_keeps_discard_cleanup(instrs[producer], params)
}

///|
fn dae2_stack_suffix_drop_value(out : Array[@lib.Instruction]) -> Unit {
  match out.last() {
    Some(leaf) if dae2_stack_suffix_discardable_leaf(leaf) => ignore(out.pop())
    Some(@lib.LocalTee(local)) => {
      ignore(out.pop())
      out.push(@lib.Instruction::local_set(local))
    }
    _ => out.push(@lib.Instruction::drop())
  }
}

///|
// A no-result control followed by a write consumes an earlier held value.
// HOT materializes that capture before the control. Its local placement can
// avoid splitting otherwise contiguous local declaration groups, so retain
// HOT lowering for this shape until raw replay reproduces that capture plan.
fn dae2_stack_suffix_needs_control_capture(
  instrs : Array[@lib.Instruction],
  position : Int32,
  context : @ir.HotModuleContext?,
  params~ : Int32 = 0,
  uniform_body_locals~ : Bool = false,
) -> Bool {
  if position == 0 {
    return false
  }
  // With one source local run, moving a body-local value to an appended HOT
  // capture cannot merge interior declaration runs. Keep its natural stack
  // form instead of adding captures throughout the function. Parameter writes
  // retain the general path because removed parameters can add other types.
  if uniform_body_locals {
    match instrs[position] {
      @lib.LocalSet(@lib.LocalIdx(raw)) if raw.to_int() >= params =>
        return false
      _ => ()
    }
  }
  match instrs[position - 1] {
    @lib.Block(@lib.VoidBlockType, _)
    | @lib.Loop(@lib.VoidBlockType, _)
    | @lib.If(@lib.VoidBlockType, _, _)
    | @lib.TryTable(@lib.VoidBlockType, _, _)
    | @lib.Try(@lib.VoidBlockType, _, _, _) => true
    @lib.Loop(@lib.TypeIdxBlockType(index), _) =>
      dae2_stack_suffix_indexed_loop_has_no_results(context, index)
    _ => false
  }
}

///|
fn dae2_stack_suffix_qualifies(
  instrs : Array[@lib.Instruction],
  plan : Dae2StackSuffixPlan,
  local_map : Array[Int32],
  reads : Array[Bool],
  params : Int32,
  writes : Dae2StackSuffixWriteDemand,
  context : @ir.HotModuleContext?,
  uniform_body_locals~ : Bool = false,
) -> Bool {
  let mut result_discards = 0
  let mut suffix_call = dae2_stack_suffix_next_call(instrs, plan, 0)
  for position in 0..<instrs.length() {
    if result_discards > 0 {
      match instrs[position] {
        @lib.LocalSet(@lib.LocalIdx(local)) =>
          if !writes.allows(local.to_int(), false) {
            return false
          }
        _ => ()
      }
      result_discards -= 1
      continue
    }
    if suffix_call >= 0 &&
      position < suffix_call &&
      position >=
      suffix_call - plan.suffixes[dae2_stack_suffix_callee(instrs[suffix_call])] {
      if !dae2_stack_suffix_discardable_leaf(instrs[position]) {
        return false
      }
      continue
    }
    if position == suffix_call {
      suffix_call = dae2_stack_suffix_next_call(instrs, plan, position + 1)
    }
    match instrs[position] {
      // Result-bearing indexed headers and exception scopes retain their
      // general HOT normalization. Only unchanged no-result indexed loops
      // preserve their complete entry and backedge stack through raw edits.
      @lib.Block(@lib.TypeIdxBlockType(_), _)
      | @lib.If(@lib.TypeIdxBlockType(_), _, _)
      | @lib.TryTable(@lib.TypeIdxBlockType(_), _, _)
      | @lib.Try(@lib.TypeIdxBlockType(_), _, _, _) => return false
      @lib.Loop(@lib.TypeIdxBlockType(index), @lib.Expr(body)) =>
        if !dae2_stack_suffix_indexed_loop_has_no_results(context, index) ||
          !dae2_stack_suffix_qualifies(
            body,
            plan,
            local_map,
            reads,
            params,
            writes,
            context,
            uniform_body_locals~,
          ) {
          return false
        }
      @lib.LocalGet(@lib.LocalIdx(raw))
      | @lib.LocalSet(@lib.LocalIdx(raw))
      | @lib.LocalTee(@lib.LocalIdx(raw)) => {
        let local = raw.reinterpret_as_int()
        if local < 0 || local >= local_map.length() {
          return false
        }
        // An unread numeric parameter write disappears before local remapping.
        // Every surviving read or write must still name an owned body slot.
        if local_map[local] < 0 &&
          (reads[local] || instrs[position] is @lib.LocalGet(_)) {
          return false
        }
        if !(instrs[position] is @lib.LocalGet(_)) &&
          !writes.allows(local, reads[local]) {
          return false
        }
        if instrs[position] is @lib.LocalSet(_) &&
          reads[local] &&
          dae2_stack_suffix_needs_control_capture(
            instrs,
            position,
            context,
            params~,
            uniform_body_locals~,
          ) {
          return false
        }
        if instrs[position] is @lib.LocalSet(_) && !reads[local] {
          if !dae2_stack_suffix_discard_qualifies(
              instrs, position, reads, params,
            ) {
            return false
          }
        }
      }
      @lib.Call(@lib.FuncIdx(raw)) | @lib.ReturnCall(@lib.FuncIdx(raw)) => {
        let callee = raw.reinterpret_as_int()
        if callee < 0 || callee >= plan.suffixes.length() {
          return false
        }
        let suffix = plan.suffixes[callee]
        if suffix < 0 || suffix > position {
          return false
        }
        for arg in (position - suffix)..<position {
          if !dae2_stack_suffix_discardable_leaf(instrs[arg]) {
            return false
          }
        }
        let results = plan.removed_results[callee]
        if instrs[position] is @lib.ReturnCall(_) && results > 0 {
          return false
        }
        if results > instrs.length() - position - 1 {
          return false
        }
        for result in 0..<results {
          let discard = instrs[position + result + 1]
          if !(discard is @lib.Drop) &&
            !(discard is @lib.LocalSet(@lib.LocalIdx(local)) &&
            !reads[local.to_int()]) {
            return false
          }
        }
        result_discards = results
      }
      @lib.Drop =>
        if !dae2_stack_suffix_discard_qualifies(instrs, position, reads, params) {
          return false
        }
      // These keep their general HOT/type-family rewrite. No guessed indirect
      // target signature or handler payload is admitted by this projection.
      @lib.CallIndirect(_, _)
      | @lib.CallRef(_)
      | @lib.ReturnCallIndirect(_, _)
      | @lib.ReturnCallRef(_)
      // General lowering normalizes result-bearing control that cannot fall
      // through and removes returns after branches. Preserve that cleanup.
      | @lib.Return => return false
      @lib.Block(_, @lib.Expr(body))
      | @lib.Loop(_, @lib.Expr(body))
      | @lib.TryTable(_, _, @lib.Expr(body)) =>
        if !dae2_stack_suffix_qualifies(
            body,
            plan,
            local_map,
            reads,
            params,
            writes,
            context,
            uniform_body_locals~,
          ) {
          return false
        }
      @lib.If(_, then_, else_) => {
        if !dae2_stack_suffix_qualifies(
            then_,
            plan,
            local_map,
            reads,
            params,
            writes,
            context,
            uniform_body_locals~,
          ) {
          return false
        }
        match else_ {
          Some(body) =>
            if !dae2_stack_suffix_qualifies(
                body,
                plan,
                local_map,
                reads,
                params,
                writes,
                context,
                uniform_body_locals~,
              ) {
              return false
            }
          None => ()
        }
      }
      @lib.Try(_, @lib.Expr(body), catches, _) => {
        if !dae2_stack_suffix_qualifies(
            body,
            plan,
            local_map,
            reads,
            params,
            writes,
            context,
            uniform_body_locals~,
          ) {
          return false
        }
        for catch_ in catches {
          let body = match catch_ {
            @lib.LegacyCatch(_, @lib.Expr(body))
            | @lib.LegacyCatchAll(@lib.Expr(body)) => body
          }
          if !dae2_stack_suffix_qualifies(
              body,
              plan,
              local_map,
              reads,
              params,
              writes,
              context,
              uniform_body_locals~,
            ) {
            return false
          }
        }
      }
      _ => ()
    }
  }
  true
}

///|
fn dae2_stack_suffix_rewrite_body(
  instrs : Array[@lib.Instruction],
  plan : Dae2StackSuffixPlan,
  local_map : Array[Int32],
  reads : Array[Bool],
) -> Array[@lib.Instruction] {
  let out = Array(capacity=instrs.length())
  let mut position = 0
  let mut suffix_call = dae2_stack_suffix_next_call(instrs, plan, 0)
  let visit_body = fn(body) {
    dae2_stack_suffix_rewrite_body(body, plan, local_map, reads)
  }
  while position < instrs.length() {
    if suffix_call >= 0 &&
      position < suffix_call &&
      position >=
      suffix_call - plan.suffixes[dae2_stack_suffix_callee(instrs[suffix_call])] {
      position = suffix_call
    }
    if position == suffix_call {
      suffix_call = dae2_stack_suffix_next_call(instrs, plan, position + 1)
    }
    let instr = instrs[position]
    match instr {
      @lib.Call(@lib.FuncIdx(raw)) | @lib.ReturnCall(@lib.FuncIdx(raw)) => {
        let callee = raw.reinterpret_as_int()
        // Preflight proves these are precisely the last, pure scalar argument
        // producers. Remove them without changing any retained producer's order.
        out.push(instr)
        position += plan.removed_results[callee] + 1
        continue
      }
      @lib.Drop => {
        dae2_stack_suffix_drop_value(out)
        position += 1
        continue
      }
      @lib.LocalTee(@lib.LocalIdx(local)) if !reads[local.to_int()] => {
        position += 1
        continue
      }
      @lib.LocalSet(@lib.LocalIdx(local)) if !reads[local.to_int()] => {
        dae2_stack_suffix_drop_value(out)
        position += 1
        continue
      }
      _ => ()
    }
    out.push(
      match instr {
        @lib.LocalGet(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_get(
            @lib.LocalIdx::new(
              local_map[raw.reinterpret_as_int()].reinterpret_as_uint(),
            ),
          )
        @lib.LocalSet(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_set(
            @lib.LocalIdx::new(
              local_map[raw.reinterpret_as_int()].reinterpret_as_uint(),
            ),
          )
        @lib.LocalTee(@lib.LocalIdx(raw)) =>
          @lib.Instruction::local_tee(
            @lib.LocalIdx::new(
              local_map[raw.reinterpret_as_int()].reinterpret_as_uint(),
            ),
          )
        _ => pass_lower_map_children(instr, visit_body)
      },
    )
    position += 1
  }
  out
}

///|
// When signatures alone demand the rewrite, literal suffix producers need no
// expression graph or control reconstruction. Preserve every control header,
// branch depth and observable operation; general mutations still use HOT.
fn dae2_rewrite_stack_suffix_function(
  plan : Dae2StackSuffixPlan,
  graph : Dae2Graph,
  info : Dae2Function,
  index : Int32,
  original : @lib.Func,
  state : Dae2StackSuffixState,
) -> (@lib.Func, Array[Int32])? {
  if state.admissions[index] != 1 ||
    plan.removed_results[index] > 0 ||
    (!info.raw_analysis && state.original_writes[index] is None) {
    return None
  }
  let @lib.Func(locals, @lib.Expr(instrs)) = original
  let local_map = Array::make(info.params.length() + locals.length(), -1)
  let numeric : Array[Int32] = []
  let reads = Array::make(local_map.length(), true)
  for param in 0..<info.params.length() {
    if !graph.used[info.param_locations[param]] {
      match info.params[param] {
        @lib.NumTypeValType(_) | @lib.VecTypeValType => {
          numeric.push(param)
          reads[param] = false
        }
        _ => ()
      }
    }
  }
  for local in info.params.length()..<reads.length() {
    reads[local] = false
  }
  if !locals.is_empty() || !numeric.is_empty() {
    dae2_stack_suffix_mark_reads(instrs, reads, plan)
  }
  // Only numeric parameters with emitted reads need a body declaration.
  // Unread writes disappear through the existing tee/set cleanup below.
  let mut retained_numeric = 0
  for slot in 0..<numeric.length() {
    let param = numeric[slot]
    if reads[param] {
      numeric[retained_numeric] = param
      retained_numeric += 1
      local_map[param] = -2
    }
  }
  numeric.truncate(retained_numeric)
  // Preserve HOT cleanup when an entry read is only part of a dead expression.
  // This narrow lane requires every relocated read to follow an unconditional
  // root-prefix write. Reuse the not-yet-published map as sparse proof marks.
  if !numeric.is_empty() {
    for instr in instrs {
      match instr {
        @lib.LocalGet(@lib.LocalIdx(local)) =>
          if local_map[local.to_int()] == -2 {
            return None
          }
        @lib.LocalSet(@lib.LocalIdx(local))
        | @lib.LocalTee(@lib.LocalIdx(local)) =>
          if local_map[local.to_int()] == -2 {
            local_map[local.to_int()] = -3
          }
        @lib.Block(_, _)
        | @lib.Loop(_, _)
        | @lib.If(_, _, _)
        | @lib.TryTable(_, _, _)
        | @lib.Try(_, _, _, _) => break
        _ => ()
      }
    }
    for param in numeric {
      if local_map[param] != -3 {
        return None
      }
    }
  }
  let mut next = 0
  for param in 0..<info.params.length() {
    if graph.used[info.param_locations[param]] {
      local_map[param] = next
      next += 1
    }
  }
  for local in info.params.length()..<local_map.length() {
    local_map[local] = next
    next += 1
  }
  for slot in 0..<numeric.length() {
    local_map[numeric[slot]] = next + numeric.length() - 1 - slot
  }
  let writes = Dae2StackSuffixWriteDemand::new(
    info,
    graph,
    state.original_writes[index],
  )
  if !dae2_stack_suffix_qualifies(
      instrs,
      plan,
      local_map,
      reads,
      info.params.length(),
      writes,
      state.context,
      uniform_body_locals=locals.run_count() == 1,
    ) {
    return None
  }
  match writes.original_writes {
    Some(original) if writes.cursor != original.length() => return None
    _ => ()
  }
  let body = dae2_stack_suffix_rewrite_body(instrs, plan, local_map, reads)
  if numeric.is_empty() {
    return Some((@lib.Func::new(locals, @lib.Expr::new(body)), local_map))
  }
  let kept_params : Array[@lib.ValType] = []
  for param in 0..<info.params.length() {
    if graph.used[info.param_locations[param]] {
      kept_params.push(info.params[param])
    }
  }
  let new_locals = locals.copy()
  for slot = numeric.length() - 1; slot >= 0; slot = slot - 1 {
    new_locals.push(info.params[numeric[slot]])
  }
  let (rewritten, capture_map) = pass_lower_compact_captures_with_map(
    @lib.Func::new(new_locals, @lib.Expr::new(body)),
    original,
    kept_params,
  )
  Some(
    (
      rewritten,
      local_map.map(fn(local) {
        if local < 0 {
          -1
        } else {
          capture_map[local]
        }
      }),
    ),
  )
}
