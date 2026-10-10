// MoonBit v0.10.14 cannot lower native debug uninitialized arrays of this
// mixed value record (#1322). Native storage is always initialized. Other
// targets keep core Array storage. Like Array, removals retain old slots until
// overwrite/growth/drop so pre-existing iterators keep the same observations.

///|
#cfg(not(target="native"))
type HotLowerValueStack = Array[HotLowerStackValue]

///|
#cfg(not(target="native"))
fn hot_lower_value_stack_new() -> HotLowerValueStack {
  []
}

///|
#cfg(target="native")
priv struct HotLowerValueStack {
  mut data : FixedArray[HotLowerStackValue]
  mut count : Int
}

///|
#cfg(target="native")
fn hot_lower_value_stack_empty() -> HotLowerStackValue {
  { node_id: 0, val_type: ValType::i32(), }
}

///|
#cfg(target="native")
fn hot_lower_value_stack_new() -> HotLowerValueStack {
  { data: FixedArray::make(0, hot_lower_value_stack_empty()), count: 0, }
}

///|
#cfg(target="native")
fn HotLowerValueStack::length(self : HotLowerValueStack) -> Int {
  self.count
}

///|
#cfg(target="native")
fn HotLowerValueStack::is_empty(self : HotLowerValueStack) -> Bool {
  self.count == 0
}

///|
#cfg(target="native")
fn HotLowerValueStack::push(
  self : HotLowerValueStack,
  value : HotLowerStackValue,
) -> Unit {
  if self.count == self.data.length() {
    let capacity = hot_lower_value_stack_growth_capacity(
      self.data.length(),
      self.count,
    )
    let grown = FixedArray::make(capacity, hot_lower_value_stack_empty())
    for i in 0..<self.count {
      grown[i] = self.data[i]
    }
    self.data = grown
  }
  self.data[self.count] = value
  self.count += 1
}

///|
#cfg(target="native")
fn HotLowerValueStack::pop(self : HotLowerValueStack) -> HotLowerStackValue? {
  if self.count == 0 {
    return None
  }
  self.count -= 1
  let value = self.data[self.count]
  Some(value)
}

///|
#cfg(target="native")
fn HotLowerValueStack::clear(self : HotLowerValueStack) -> Unit {
  self.count = 0
}

///|
#cfg(target="native")
fn HotLowerValueStack::copy(self : HotLowerValueStack) -> HotLowerValueStack {
  let data = FixedArray::make(self.count, hot_lower_value_stack_empty())
  for i in 0..<self.count {
    data[i] = self.data[i]
  }
  { data, count: self.count, }
}

///|
#cfg(target="native")
#alias("_[_]")
fn HotLowerValueStack::get(
  self : HotLowerValueStack,
  index : Int,
) -> HotLowerStackValue {
  if index < 0 || index >= self.count {
    abort("Hot lower value stack index out of bounds")
  }
  self.data[index]
}

///|
#cfg(target="native")
#alias("_[_]=_")
fn HotLowerValueStack::set(
  self : HotLowerValueStack,
  index : Int,
  value : HotLowerStackValue,
) -> Unit {
  if index < 0 || index >= self.count {
    abort("Hot lower value stack index out of bounds")
  }
  self.data[index] = value
}

///|
#cfg(target="native")
fn HotLowerValueStack::iter(
  self : HotLowerValueStack,
) -> Iter[HotLowerStackValue] {
  let data = self.data
  let count = self.count
  let mut index = 0
  Iter::new(
    fn() {
      if index >= count {
        None
      } else {
        let value = data[index]
        index += 1
        Some(value)
      }
    },
    size_hint=count,
  )
}

///|
#cfg(target="native")
fn HotLowerValueStack::truncate(
  self : HotLowerValueStack,
  length : Int,
) -> Unit {
  if length < 0 || length >= self.count {
    return
  }
  self.count = length
}

///|
#cfg(target="native")
fn HotLowerValueStack::any(
  self : HotLowerValueStack,
  predicate : (HotLowerStackValue) -> Bool,
) -> Bool {
  for i in 0..<self.count {
    if predicate(self.data[i]) {
      return true
    }
  }
  false
}

///|
#cfg(target="native")
fn hot_lower_value_stack_makei(
  count : Int,
  make : (Int) -> HotLowerStackValue,
) -> HotLowerValueStack {
  let data = FixedArray::make(count, hot_lower_value_stack_empty())
  for i in 0..<count {
    data[i] = make(i)
  }
  { data, count, }
}

///|
#cfg(not(target="native"))
fn hot_lower_value_stack_makei(
  count : Int,
  make : (Int) -> HotLowerStackValue,
) -> HotLowerValueStack {
  Array::makei(count, make)
}

///|
#cfg(target="native")
fn hot_lower_value_stack_growth_capacity(capacity : Int, count : Int) -> Int {
  let required = count + 1
  if required <= count {
    abort("Hot lower value stack capacity overflow")
  }
  if capacity == 0 {
    return 8
  }
  let doubled = capacity * 2
  if doubled <= capacity {
    required
  } else {
    doubled
  }
}

///|
#cfg(target="native")
fn HotLowerValueStack::last(self : HotLowerValueStack) -> HotLowerStackValue? {
  if self.count == 0 {
    None
  } else {
    Some(self.data[self.count - 1])
  }
}

///|
#cfg(target="native")
fn[T] HotLowerValueStack::map(
  self : HotLowerValueStack,
  make : (HotLowerStackValue) -> T,
) -> Array[T] {
  Array::makei(self.count, fn(index) { make(self.data[index]) })
}
