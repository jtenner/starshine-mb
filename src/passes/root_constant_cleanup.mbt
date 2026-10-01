///|
#valtype
priv struct SlRootConstant {
  store : Int
  literal : @lib.Instruction
  wrapped : Bool
  dropped_tee : Bool
  growth : Int
  saved : Int
}

///|
fn SlRootConstant::new(
  store : Int,
  literal : @lib.Instruction,
  wrapped : Bool,
  dropped_tee : Bool,
  growth : Int,
  saved : Int,
) -> SlRootConstant {
  { store, literal, wrapped, dropped_tee, growth, saved, }
}

///|
fn sl_root_constant_bytes(instr : @lib.Instruction) -> Int {
  match instr {
    @lib.I32Const(@lib.I32(value)) => {
      let mut value = value
      let mut bytes = 2
      while value < -64 || value > 63 {
        value = value >> 7
        bytes += 1
      }
      bytes
    }
    @lib.I64Const(@lib.I64(value)) => {
      let mut value = value
      let mut bytes = 2
      while value < -64L || value > 63L {
        value = value >> 7
        bytes += 1
      }
      bytes
    }
    @lib.F32Const(_) => 5
    @lib.F64Const(_) => 9
    _ => 0
  }
}

///|
// Visit all writers, including unreachable tails and every exceptional arm.
// Root ordinal is inherited by children: only roots after the assignment are
// dominated by it. Budgets are small encoded-byte savings, saturated at -1.
fn sl_root_constant_census(
  body : Array[@lib.Instruction],
  root : Int,
  top : Bool,
  indices : Map[Int, Int],
  candidates : Array[SlRootConstant],
  writes : Array[Int],
  reads : Array[Bool],
  budgets : Array[Int],
) -> Unit {
  for i = 0; i < body.length(); i = i + 1 {
    let ordinal = if top { i } else { root }
    match body[i] {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
        if indices.get(raw.reinterpret_as_int()) is Some(id) {
          writes[id] = (writes[id] + 1).min(2)
        }
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        if indices.get(raw.reinterpret_as_int()) is Some(id) &&
          ordinal > candidates[id].store {
          reads[id] = true
          budgets[id] = (budgets[id] - candidates[id].growth).max(-1)
        }
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        sl_root_constant_census(
          nested, ordinal, false, indices, candidates, writes, reads, budgets,
        )
      @lib.If(_, yes, no) => {
        sl_root_constant_census(
          yes, ordinal, false, indices, candidates, writes, reads, budgets,
        )
        if no is Some(no) {
          sl_root_constant_census(
            no, ordinal, false, indices, candidates, writes, reads, budgets,
          )
        }
      }
      @lib.Try(_, @lib.Expr(nested), catches, _) => {
        sl_root_constant_census(
          nested, ordinal, false, indices, candidates, writes, reads, budgets,
        )
        for catch_ in catches {
          let @lib.Expr(handler) = match catch_ {
            @lib.LegacyCatch(_, handler) | @lib.LegacyCatchAll(handler) =>
              handler
          }
          sl_root_constant_census(
            handler, ordinal, false, indices, candidates, writes, reads, budgets,
          )
        }
      }
      _ => ()
    }
  }
}

///|
fn sl_root_constant_rewrite(
  body : Array[@lib.Instruction],
  root : Int,
  top : Bool,
  indices : Map[Int, Int],
  candidates : Array[SlRootConstant],
  selected : Array[Bool],
  removed : Array[Bool],
) -> Array[@lib.Instruction] {
  let mut output = body
  let mut changed = false
  for i = 0; i < body.length(); i = i + 1 {
    if top && removed[i] {
      if !changed {
        output = body[:i].to_array()
        changed = true
      }
      continue
    }
    let ordinal = if top { i } else { root }
    let instr = body[i]
    let next = match instr {
      @lib.LocalGet(@lib.LocalIdx(raw)) =>
        match indices.get(raw.reinterpret_as_int()) {
          Some(id) if selected[id] && ordinal > candidates[id].store =>
            candidates[id].literal
          _ => instr
        }
      @lib.Block(bt, @lib.Expr(nested)) => {
        let next = sl_root_constant_rewrite(
          nested, ordinal, false, indices, candidates, selected, removed,
        )
        if physical_equal(next, nested) {
          instr
        } else {
          @lib.Instruction::block(bt, @lib.Expr::new(next))
        }
      }
      @lib.Loop(bt, @lib.Expr(nested)) => {
        let next = sl_root_constant_rewrite(
          nested, ordinal, false, indices, candidates, selected, removed,
        )
        if physical_equal(next, nested) {
          instr
        } else {
          @lib.Instruction::loop_(bt, @lib.Expr::new(next))
        }
      }
      @lib.TryTable(bt, catches, @lib.Expr(nested)) => {
        let next = sl_root_constant_rewrite(
          nested, ordinal, false, indices, candidates, selected, removed,
        )
        if physical_equal(next, nested) {
          instr
        } else {
          @lib.Instruction::try_table(bt, catches, @lib.Expr::new(next))
        }
      }
      @lib.If(bt, yes, no) => {
        let next_yes = sl_root_constant_rewrite(
          yes, ordinal, false, indices, candidates, selected, removed,
        )
        let next_no = match no {
          Some(no) =>
            Some(
              sl_root_constant_rewrite(
                no, ordinal, false, indices, candidates, selected, removed,
              ),
            )
          None => None
        }
        let same_no = match (no, next_no) {
          (Some(a), Some(b)) => physical_equal(a, b)
          (None, None) => true
          _ => false
        }
        if physical_equal(next_yes, yes) && same_no {
          instr
        } else {
          @lib.Instruction::if_(bt, next_yes, next_no)
        }
      }
      @lib.Try(bt, @lib.Expr(nested), catches, delegate_) => {
        let next_body = sl_root_constant_rewrite(
          nested, ordinal, false, indices, candidates, selected, removed,
        )
        let mut next_catches = catches
        let mut catches_changed = false
        for j = 0; j < catches.length(); j = j + 1 {
          let catch_ = catches[j]
          let next_catch = match catch_ {
            @lib.LegacyCatch(tag, @lib.Expr(handler)) => {
              let next = sl_root_constant_rewrite(
                handler, ordinal, false, indices, candidates, selected, removed,
              )
              if physical_equal(next, handler) {
                catch_
              } else {
                @lib.LegacyCatch::tagged(tag, @lib.Expr::new(next))
              }
            }
            @lib.LegacyCatchAll(@lib.Expr(handler)) => {
              let next = sl_root_constant_rewrite(
                handler, ordinal, false, indices, candidates, selected, removed,
              )
              if physical_equal(next, handler) {
                catch_
              } else {
                @lib.LegacyCatch::all(@lib.Expr::new(next))
              }
            }
          }
          if !physical_equal(next_catch, catch_) {
            if !catches_changed {
              next_catches = catches.copy()
              catches_changed = true
            }
            next_catches[j] = next_catch
          }
        }
        if physical_equal(next_body, nested) && !catches_changed {
          instr
        } else {
          @lib.Instruction::try_(
            bt,
            @lib.Expr::new(next_body),
            next_catches,
            delegate=delegate_,
          )
        }
      }
      _ => instr
    }
    if !physical_equal(next, instr) && !changed {
      output = body[:i].to_array()
      changed = true
    }
    if changed {
      output.push(next)
    }
  }
  output
}

///|
// Pure root literals with one static writer can replace dominated reads across
// effects, traps and handlers. Retain literal objects (including float bits),
// earlier reads, all other instructions, and reject encoded-byte growth.
fn sl_inline_root_constants(
  body : Array[@lib.Instruction],
) -> Array[@lib.Instruction] {
  let mut candidates : Array[SlRootConstant]? = None
  let mut indices : Map[Int, Int]? = None
  for i = 0; i < body.length(); i = i + 1 {
    let mut literal = body[i]
    let mut write = body[i]
    let mut dropped_tee = false
    let mut wrapped = false
    match body[i] {
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([value, @lib.LocalSet(_) as store])
      ) => {
        literal = value
        write = store
        wrapped = true
      }
      @lib.Block(
        @lib.VoidBlockType,
        @lib.Expr([value, @lib.LocalTee(_) as store, @lib.Drop])
      ) => {
        literal = value
        write = store
        dropped_tee = true
        wrapped = true
      }
      _ => {
        if i == 0 {
          continue
        }
        dropped_tee = body[i] is @lib.LocalTee(_) &&
          i + 1 < body.length() &&
          body[i + 1] is @lib.Drop
        if !(body[i] is @lib.LocalSet(_)) && !dropped_tee {
          continue
        }
        literal = body[i - 1]
      }
    }
    let literal_bytes = sl_root_constant_bytes(literal)
    if literal_bytes == 0 {
      continue
    }
    let local = match write {
      @lib.LocalSet(@lib.LocalIdx(raw)) | @lib.LocalTee(@lib.LocalIdx(raw)) =>
        raw
      _ => continue
    }
    if candidates is None {
      candidates = Some([])
      indices = Some({})
    }
    let row = candidates.unwrap()
    let mut value = local
    let mut local_bytes = 2
    while value >= 128U {
      value = value >> 7
      local_bytes += 1
    }
    indices.unwrap()[local.reinterpret_as_int()] = row.length()
    row.push(
      SlRootConstant::new(
        i,
        literal,
        wrapped,
        dropped_tee,
        (literal_bytes - local_bytes).max(0),
        literal_bytes +
        local_bytes +
        (if dropped_tee { 1 } else { 0 }) +
        (if wrapped { 3 } else { 0 }),
      ),
    )
  }
  guard candidates is Some(candidates) else { return body }
  let indices = indices.unwrap()
  let writes = Array::make(candidates.length(), 0)
  let reads = Array::make(candidates.length(), false)
  let budgets = candidates.map(fn(candidate) { candidate.saved })
  sl_root_constant_census(
    body, 0, true, indices, candidates, writes, reads, budgets,
  )
  let selected = Array::makei(candidates.length(), fn(id) {
    writes[id] == 1 && reads[id] && budgets[id] >= 0
  })
  if !selected.contains(true) {
    return body
  }
  let removed = Array::make(body.length(), false)
  for id = 0; id < candidates.length(); id = id + 1 {
    if selected[id] {
      let candidate = candidates[id]
      removed[candidate.store] = true
      if !candidate.wrapped {
        removed[candidate.store - 1] = true
        if candidate.dropped_tee {
          removed[candidate.store + 1] = true
        }
      }
    }
  }
  sl_root_constant_rewrite(
    body, 0, true, indices, candidates, selected, removed,
  )
}
