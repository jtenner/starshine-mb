///|
pub struct Bitset {
  size : Int
  words : Array[UInt64]
} derive(Eq, Show, Debug)

///|
const BITSET_WORD_BITS : Int = 64

///|
fn bitset_require_size(size : Int) -> Unit {
  if size < 0 {
    abort("bitset size must be non-negative")
  }
}

///|
fn bitset_word_count(size : Int) -> Int {
  if size == 0 {
    return 0
  }
  (size + BITSET_WORD_BITS - 1) / BITSET_WORD_BITS
}

///|
fn bitset_last_word_mask(size : Int) -> UInt64 {
  let rem = size % BITSET_WORD_BITS
  if rem == 0 {
    return UInt64::lnot(0UL)
  }
  (1UL << rem) - 1UL
}

///|
fn bitset_word_mask(bitset : Bitset, word_idx : Int) -> UInt64 {
  if bitset.words.length() == 0 ||
    word_idx < 0 ||
    word_idx >= bitset.words.length() {
    return 0UL
  }
  if word_idx + 1 == bitset.words.length() {
    return bitset_last_word_mask(bitset.size)
  }
  UInt64::lnot(0UL)
}

///|
fn bitset_mask_unused_high_bits(bitset : Bitset) -> Unit {
  if bitset.words.length() == 0 {
    return
  }
  let last = bitset.words.length() - 1
  bitset.words[last] = bitset.words[last] & bitset_word_mask(bitset, last)
}

///|
fn bitset_require_index(bitset : Bitset, idx : Int) -> Unit {
  if idx < 0 || idx >= bitset.size {
    abort("bitset index out of bounds")
  }
}

///|
fn bitset_require_compatible(lhs : Bitset, rhs : Bitset) -> Unit {
  if lhs.size != rhs.size {
    abort("bitset sizes must match")
  }
}

///|
fn bitset_word_index(idx : Int) -> Int {
  idx / BITSET_WORD_BITS
}

///|
fn bitset_word_bit_mask(idx : Int) -> UInt64 {
  1UL << (idx % BITSET_WORD_BITS)
}

///|
pub fn bitset_new(size : Int) -> Bitset {
  bitset_require_size(size)
  { size, words: Array::make(bitset_word_count(size), 0UL) }
}

///|
pub fn bitset_set(bitset : Bitset, idx : Int) -> Bool {
  bitset_require_index(bitset, idx)
  let word_idx = bitset_word_index(idx)
  let mask = bitset_word_bit_mask(idx)
  let before = bitset.words[word_idx]
  let after = before | mask
  bitset.words[word_idx] = after
  after != before
}

///|
pub fn bitset_clear(bitset : Bitset, idx : Int) -> Bool {
  bitset_require_index(bitset, idx)
  let word_idx = bitset_word_index(idx)
  let mask = bitset_word_bit_mask(idx)
  let before = bitset.words[word_idx]
  let after = before & UInt64::lnot(mask)
  bitset.words[word_idx] = after
  after != before
}

///|
pub fn bitset_contains(bitset : Bitset, idx : Int) -> Bool {
  bitset_require_index(bitset, idx)
  let word_idx = bitset_word_index(idx)
  (bitset.words[word_idx] & bitset_word_bit_mask(idx)) != 0UL
}

///|
pub fn bitset_union_into(dst : Bitset, src : Bitset) -> Bool {
  bitset_require_compatible(dst, src)
  let mut changed = false
  for idx = 0; idx < dst.words.length(); idx = idx + 1 {
    let before = dst.words[idx]
    let after = before | src.words[idx]
    if after != before {
      changed = true
      dst.words[idx] = after
    }
  }
  bitset_mask_unused_high_bits(dst)
  changed
}

///|
pub fn bitset_intersect_into(dst : Bitset, src : Bitset) -> Bool {
  bitset_require_compatible(dst, src)
  let mut changed = false
  for idx = 0; idx < dst.words.length(); idx = idx + 1 {
    let before = dst.words[idx]
    let after = before & src.words[idx]
    if after != before {
      changed = true
      dst.words[idx] = after
    }
  }
  bitset_mask_unused_high_bits(dst)
  changed
}

///|
pub fn bitset_difference_into(dst : Bitset, src : Bitset) -> Bool {
  bitset_require_compatible(dst, src)
  let mut changed = false
  for idx = 0; idx < dst.words.length(); idx = idx + 1 {
    let before = dst.words[idx]
    let after = before & UInt64::lnot(src.words[idx])
    if after != before {
      changed = true
      dst.words[idx] = after
    }
  }
  bitset_mask_unused_high_bits(dst)
  changed
}

///|
pub fn bitset_equals(lhs : Bitset, rhs : Bitset) -> Bool {
  bitset_require_compatible(lhs, rhs)
  lhs.words == rhs.words
}

///|
pub fn bitset_for_each_set_bit(bitset : Bitset, visit : (Int) -> Unit) -> Unit {
  for word_idx = 0; word_idx < bitset.words.length(); word_idx = word_idx + 1 {
    let word = bitset.words[word_idx] & bitset_word_mask(bitset, word_idx)
    if word == 0UL {
      continue
    }
    let base = word_idx * BITSET_WORD_BITS
    for bit_idx = 0
        bit_idx < BITSET_WORD_BITS && base + bit_idx < bitset.size
        bit_idx = bit_idx + 1 {
      if (word & (1UL << bit_idx)) != 0UL {
        visit(base + bit_idx)
      }
    }
  }
}
