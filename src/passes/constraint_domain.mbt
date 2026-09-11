///|
// Unsigned bit-pattern spans also represent signed ranges. In particular a
// signed interval crossing zero has two unsigned spans, never one signed hull.
priv struct CaSpan {
  lo : UInt64
  hi : UInt64
} derive(Eq, @debug.Debug)

///|
priv struct CaRange {
  bits : Int
  spans : Array[CaSpan]
} derive(Eq, @debug.Debug)

///|
fn ca_max(bits : Int) -> UInt64 {
  if bits == 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << bits) - 1UL
  }
}

///|
fn ca_range(bits : Int, spans : Array[CaSpan]) -> CaRange {
  let sorted = spans.copy()
  sorted.sort_by(fn(a, b) { a.lo.compare(b.lo) })
  let merged : Array[CaSpan] = []
  for span in sorted {
    if span.lo > span.hi {
      continue
    }
    let n = merged.length()
    if n > 0 &&
      (
        span.lo <= merged[n - 1].hi ||
        (merged[n - 1].hi < ca_max(bits) && span.lo == merged[n - 1].hi + 1UL)
      ) {
      let old = merged[n - 1]
      merged[n - 1] = {
        lo: old.lo,
        hi: if old.hi > span.hi {
          old.hi
        } else {
          span.hi
        },
      }
    } else {
      merged.push(span)
    }
  }
  // Keep at most two spans. Bridging the smallest gap is an approximation
  // toward MORE possible values, so bounded storage cannot strengthen a fact.
  while merged.length() > 2 {
    let mut best = 0
    for i = 1; i + 1 < merged.length(); i = i + 1 {
      if merged[i + 1].lo - merged[i].hi < merged[best + 1].lo - merged[best].hi {
        best = i
      }
    }
    merged[best] = { lo: merged[best].lo, hi: merged[best + 1].hi, }
    ignore(merged.remove(best + 1))
  }
  { bits, spans: merged, }
}

///|
fn ca_top(bits : Int) -> CaRange {
  ca_range(bits, [{ lo: 0UL, hi: ca_max(bits), }])
}

///|
fn ca_exact(bits : Int, value : UInt64) -> CaRange {
  let value = value & ca_max(bits)
  ca_range(bits, [{ lo: value, hi: value, }])
}

///|
fn ca_single(range : CaRange) -> UInt64? {
  match range.spans {
    [span] if span.lo == span.hi => Some(span.lo)
    _ => None
  }
}

///|
fn ca_contains(range : CaRange, value : UInt64) -> Bool {
  range.spans.any(fn(span) { span.lo <= value && value <= span.hi })
}

///|
fn ca_union(a : CaRange, b : CaRange) -> CaRange {
  let spans = a.spans.copy()
  spans.append(b.spans)
  ca_range(a.bits, spans)
}

///|
fn ca_intersect(a : CaRange, b : CaRange) -> CaRange {
  let spans : Array[CaSpan] = []
  for x in a.spans {
    for y in b.spans {
      let lo = if x.lo > y.lo { x.lo } else { y.lo }
      let hi = if x.hi < y.hi { x.hi } else { y.hi }
      if lo <= hi {
        spans.push({ lo, hi, })
      }
    }
  }
  ca_range(a.bits, spans)
}

///|
fn ca_add(range : CaRange, increment : UInt64) -> CaRange {
  let mask = ca_max(range.bits)
  let spans : Array[CaSpan] = []
  for span in range.spans {
    let lo = (span.lo + increment) & mask
    let hi = (span.hi + increment) & mask
    if lo <= hi {
      spans.push({ lo, hi, })
    } else {
      spans.push({ lo: 0UL, hi, })
      spans.push({ lo, hi: mask, })
    }
  }
  ca_range(range.bits, spans)
}

///|
// Relation bits are LT=1, EQ=2, GT=4. Swapping operands exchanges LT/GT;
// negating a predicate complements all three bits. These are different maps.
fn ca_flip(relation : Int) -> Int {
  ((relation & 1) << 2) | (relation & 2) | ((relation & 4) >> 2)
}

///|
fn ca_not(relation : Int) -> Int {
  relation ^ 7
}

///|
fn ca_relation_range(
  bits : Int,
  relation : Int,
  signed : Bool,
  value : UInt64,
) -> CaRange {
  let mask = ca_max(bits)
  let sign = if signed { 1UL << (bits - 1) } else { 0UL }
  let rank = value ^ sign
  let ranked : Array[CaSpan] = []
  if (relation & 1) != 0 && rank > 0UL {
    ranked.push({ lo: 0UL, hi: rank - 1UL, })
  }
  if (relation & 2) != 0 {
    ranked.push({ lo: rank, hi: rank, })
  }
  if (relation & 4) != 0 && rank < mask {
    ranked.push({ lo: rank + 1UL, hi: mask, })
  }
  // Rotating the ordered signed rank by the sign bit recovers bit patterns.
  ca_add(ca_range(bits, ranked), sign)
}

///|
fn ca_relation_possible(a : CaRange, b : CaRange, signed : Bool) -> Int {
  let sign = if signed { 1UL << (a.bits - 1) } else { 0UL }
  let left = ca_add(a, sign)
  let right = ca_add(b, sign)
  let mut possible = 0
  for x in left.spans {
    for y in right.spans {
      if x.lo < y.hi {
        possible = possible | 1
      }
      if x.lo <= y.hi && y.lo <= x.hi {
        possible = possible | 2
      }
      if x.hi > y.lo {
        possible = possible | 4
      }
    }
  }
  possible
}

///|
fn ca_widen(
  previous : CaRange,
  next : CaRange,
  thresholds : Array[UInt64],
) -> CaRange {
  if previous == next {
    return next
  }
  // Each endpoint moves outward only through finitely many source thresholds.
  // A changed span topology is widened to top rather than interpreted in a loop.
  if previous.spans.length() != next.spans.length() {
    return ca_top(next.bits)
  }
  let spans : Array[CaSpan] = []
  for i = 0; i < next.spans.length(); i = i + 1 {
    let old = previous.spans[i]
    let span = next.spans[i]
    let mut lo = span.lo
    let mut hi = span.hi
    if lo < old.lo {
      lo = 0UL
      for threshold in thresholds {
        if threshold <= span.lo && threshold > lo {
          lo = threshold
        }
      }
    }
    if hi > old.hi {
      hi = ca_max(next.bits)
      for threshold in thresholds {
        if threshold >= span.hi && threshold < hi {
          hi = threshold
        }
      }
    }
    spans.push({ lo, hi, })
  }
  ca_range(next.bits, spans)
}
