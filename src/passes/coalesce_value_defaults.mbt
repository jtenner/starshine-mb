///|
// The interner never removes keys. Numeric defaults therefore retain their
// first interned identity throughout this one analysis, including explicit
// zero writes. Preserve the original key and ID assignment on the first query.
fn cl_default_identity(
  interner : CLValueInterner,
  ty : @lib.ValType,
  formats? : Array[Int]? = None,
) -> Int {
  let slot = if ty == @lib.ValType::i32() {
    0
  } else if ty == @lib.ValType::i64() {
    1
  } else if ty == @lib.ValType::f32() {
    2
  } else if ty == @lib.ValType::f64() {
    3
  } else if ty == @lib.ValType::v128() {
    4
  } else {
    -1
  }
  let cache = if slot < 0 {
    None
  } else {
    match interner.numeric_defaults {
      Some(cache) => Some(cache)
      None => {
        let cache = Array::make(5, -1)
        interner.numeric_defaults = Some(cache)
        Some(cache)
      }
    }
  }
  if cache is Some(values) && values[slot] >= 0 {
    return values[slot]
  }
  match formats {
    Some(count) => count[0] += 1
    None => ()
  }
  let value = interner.intern("default:\{@debug.to_string(ty)}")
  match cache {
    Some(values) => values[slot] = value
    None => ()
  }
  value
}
