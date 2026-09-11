///|
// At most 64 predicates, each with a three-bit relation mask. Insertion only
// intersects an existing mask; equality substitution can therefore add at most
// 64 predicates and strictly tighten each at most twice before convergence.
fn ca_record_relation(
  state : CaState,
  left : Int,
  right : Int,
  bits : Int,
  signed : Bool,
  relation : Int,
) -> Unit {
  let work : Array[CaRelation] = [{ left, right, bits, signed, relation, }]
  for cursor = 0; cursor < work.length(); cursor = cursor + 1 {
    let next = work[cursor]
    if next.left < 0 || next.right < 0 {
      continue
    }
    if next.left == next.right {
      if (next.relation & 2) == 0 {
        state.reachable = false
      }
      continue
    }
    let fact = if next.left < next.right {
      next
    } else {
      {
        ..next,
        left: next.right,
        right: next.left,
        relation: ca_flip(next.relation),
      }
    }
    let mut position = -1
    for i = 0; i < state.relations.length(); i = i + 1 {
      let old = state.relations[i]
      if old.left == fact.left &&
        old.right == fact.right &&
        old.bits == fact.bits &&
        old.signed == fact.signed {
        position = i
        break
      }
    }
    let fact = if position >= 0 {
      let old = state.relations[position]
      let mask = old.relation & fact.relation
      if mask == old.relation {
        continue
      }
      { ..fact, relation: mask, }
    } else {
      fact
    }
    if fact.relation == 0 {
      state.reachable = false
      return
    }
    if position >= 0 {
      state.relations[position] = fact
    } else {
      if state.relations.length() >= 64 {
        continue
      }
      state.relations.push(fact)
    }
    // Equality substitutes either endpoint without changing signedness. It
    // never turns signed ordering into unsigned ordering or negates a relation.
    for old in state.relations {
      if old.bits != fact.bits {
        continue
      }
      if fact.relation == 2 {
        for pair in [(fact.left, fact.right), (fact.right, fact.left)] {
          let (from, to) = pair
          if old.left == from {
            work.push({ ..old, left: to, })
          }
          if old.right == from {
            work.push({ ..old, right: to, })
          }
        }
      }
      if old.relation == 2 {
        for pair in [(old.left, old.right), (old.right, old.left)] {
          let (from, to) = pair
          if fact.left == from {
            work.push({ ..fact, left: to, })
          }
          if fact.right == from {
            work.push({ ..fact, right: to, })
          }
        }
      }
    }
  }
  state.relations.sort_by(fn(a, b) {
    if a.left != b.left {
      a.left - b.left
    } else if a.right != b.right {
      a.right - b.right
    } else if a.bits != b.bits {
      a.bits - b.bits
    } else {
      a.signed.compare(b.signed)
    }
  })
}

///|
fn ca_equal_locals(state : CaState, index : Int) -> Array[Int] {
  let locals = [index]
  for cursor = 0; cursor < locals.length(); cursor = cursor + 1 {
    let current = locals[cursor]
    for fact in state.relations {
      if fact.relation != 2 {
        continue
      }
      let other = if fact.left == current {
        fact.right
      } else if fact.right == current {
        fact.left
      } else {
        -1
      }
      if other >= 0 && !locals.contains(other) {
        locals.push(other)
      }
    }
  }
  locals
}
