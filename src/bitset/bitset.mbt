///|
pub struct BitSet {
  mut size : Int
  mut words : FixedArray[UInt64]
} derive(Eq, Debug)

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
fn bitset_mask_unused_high_bits(values : BitSet) -> Unit {
  if values.words.length() == 0 {
    return
  }
  let last = values.words.length() - 1
  values.words[last] = values.words[last] & bitset_last_word_mask(values.size)
}

///|
fn bitset_require_index(values : BitSet, index : Int) -> Unit {
  if index < 0 || index >= values.size {
    abort("bitset index out of bounds")
  }
}

///|
fn bitset_word_index(index : Int) -> Int {
  index / BITSET_WORD_BITS
}

///|
fn bitset_word_bit_mask(index : Int) -> UInt64 {
  1UL << (index % BITSET_WORD_BITS)
}

///|
#as_free_fn
pub fn BitSet::new(size : Int) -> BitSet {
  bitset_require_size(size)
  { size, words: FixedArray::make(bitset_word_count(size), 0UL) }
}

///|
#as_free_fn
pub fn BitSet::make(size : Int, value : Bool) -> BitSet {
  bitset_require_size(size)
  let fill = if value { UInt64::lnot(0UL) } else { 0UL }
  let values = { size, words: FixedArray::make(bitset_word_count(size), fill) }
  bitset_mask_unused_high_bits(values)
  values
}

///|
pub fn BitSet::length(self : BitSet) -> Int {
  self.size
}

///|
pub fn BitSet::copy(self : BitSet) -> BitSet {
  { size: self.size, words: self.words.copy() }
}

///|
pub fn BitSet::grow(self : BitSet, size : Int, fill? : Bool = false) -> Unit {
  bitset_require_size(size)
  if size <= self.size {
    return
  }
  let old_size = self.size
  let new_word_count = bitset_word_count(size)
  if new_word_count != self.words.length() {
    let fill_word = if fill { UInt64::lnot(0UL) } else { 0UL }
    let words = FixedArray::make(new_word_count, fill_word)
    for i = 0; i < self.words.length(); i = i + 1 {
      words[i] = self.words[i]
    }
    self.words = words
  }
  self.size = size
  if fill {
    for index = old_size; index < size; index = index + 1 {
      self[index] = true
    }
  }
  bitset_mask_unused_high_bits(self)
}

///|
#alias("_[_]")
pub fn BitSet::at(self : BitSet, index : Int) -> Bool {
  bitset_require_index(self, index)
  let word_idx = bitset_word_index(index)
  (self.words[word_idx] & bitset_word_bit_mask(index)) != 0UL
}

///|
#alias("_[_]=_")
pub fn BitSet::set(self : BitSet, index : Int, value : Bool) -> Unit {
  bitset_require_index(self, index)
  let word_idx = bitset_word_index(index)
  let mask = bitset_word_bit_mask(index)
  if value {
    self.words[word_idx] = self.words[word_idx] | mask
  } else {
    self.words[word_idx] = self.words[word_idx] & UInt64::lnot(mask)
  }
}

///|
pub fn BitSet::fill(self : BitSet, value : Bool) -> Unit {
  let fill = if value { UInt64::lnot(0UL) } else { 0UL }
  for i = 0; i < self.words.length(); i = i + 1 {
    self.words[i] = fill
  }
  bitset_mask_unused_high_bits(self)
}
